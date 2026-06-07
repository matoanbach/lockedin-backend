package com.lockdin.lockdin_app

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Process
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.time.ZoneId

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPermissionStatus" -> result.success(getPermissionStatus())
                "openUsageAccessSettings" -> {
                    openUsageAccessSettings()
                    result.success(null)
                }
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(null)
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
                "cacheBackendBaseUrl" -> {
                    val baseUrl = call.argument<String>("baseUrl")
                    if (!baseUrl.isNullOrBlank()) {
                        NativeUsageUploader.cacheBaseUrl(this, baseUrl)
                    }
                    result.success(null)
                }
                "flushPendingUsageUploads" -> {
                    NativeUsageUploader.flushPendingUploads(this) { summary ->
                        result.success(summary)
                    }
                }
                "cacheRuleStatuses" -> {
                    val statuses = call.argument<List<Map<String, Any?>>>("statuses") ?: emptyList()
                    RuleEnforcementStore.cacheRuleStatuses(this, statuses)
                    result.success(null)
                }
                "consumePendingIntervention" -> {
                    result.success(RuleEnforcementStore.consumePendingIntervention(this))
                }
                "collectUsageEvents" -> {
                    if (!hasUsageAccess()) {
                        result.error(
                            "usage_access_denied",
                            "Usage Access has not been granted.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    val days = call.argument<Int>("days") ?: DEFAULT_SYNC_DAYS
                    result.success(collectUsageEvents(days))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getPermissionStatus(): Map<String, Boolean> {
        return mapOf(
            "usageAccess" to hasUsageAccess(),
            "notifications" to NotificationManagerCompat.from(this).areNotificationsEnabled(),
            "accessibility" to RuleEnforcementStore.isAccessibilityServiceEnabled(this),
        )
    }

    private fun hasUsageAccess(): Boolean {
        val appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOpsManager.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName,
            )
        } else {
            appOpsManager.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName,
            )
        }

        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings() {
        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
    }

    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.parse("package:$packageName")
            }
        }

        startActivity(intent)
    }

    private fun openAccessibilitySettings() {
        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
    }

    private fun collectUsageEvents(days: Int): List<Map<String, Any?>> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTimeMillis = System.currentTimeMillis()
        val startTimeMillis = endTimeMillis - days.coerceAtLeast(1) * MILLIS_PER_DAY
        val events = usageStatsManager.queryEvents(startTimeMillis, endTimeMillis)
        val event = UsageEvents.Event()
        val openSessions = mutableMapOf<String, Long>()
        val usageSessions = mutableListOf<Map<String, Any?>>()
        val timeZoneId = ZoneId.systemDefault().id

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName ?: continue
            if (!shouldTrackPackage(packageName)) {
                continue
            }

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND,
                -> openSessions.putIfAbsent(packageName, event.timeStamp)

                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.MOVE_TO_BACKGROUND,
                -> {
                    val sessionStart = openSessions.remove(packageName) ?: continue
                    if (event.timeStamp <= sessionStart) {
                        continue
                    }

                    appendUsageSlices(
                        usageSessions = usageSessions,
                        packageName = packageName,
                        startedAtMillis = sessionStart,
                        endedAtMillis = event.timeStamp,
                        timeZoneId = timeZoneId,
                    )
                }
            }
        }

        for ((packageName, sessionStart) in openSessions) {
            if (endTimeMillis <= sessionStart) {
                continue
            }

            appendUsageSlices(
                usageSessions = usageSessions,
                packageName = packageName,
                startedAtMillis = sessionStart,
                endedAtMillis = endTimeMillis,
                timeZoneId = timeZoneId,
            )
        }

        return usageSessions.sortedBy { it["startedAt"] as String }
    }

    private fun appendUsageSlices(
        usageSessions: MutableList<Map<String, Any?>>,
        packageName: String,
        startedAtMillis: Long,
        endedAtMillis: Long,
        timeZoneId: String,
    ) {
        if (endedAtMillis <= startedAtMillis) {
            return
        }

        val metadata = resolveAppMetadata(packageName)
        for ((segmentStart, segmentEnd) in subtractUploadedIntervals(packageName, startedAtMillis, endedAtMillis)) {
            var sliceStart = segmentStart
            while (sliceStart < segmentEnd) {
                val sliceEnd = minOf(sliceStart + MILLIS_PER_MINUTE, segmentEnd)
                usageSessions += mapOf(
                    "sourceEventId" to "android:$packageName:$sliceStart:$sliceEnd",
                    "appId" to packageName,
                    "appName" to metadata.appName,
                    "category" to metadata.category,
                    "startedAt" to Instant.ofEpochMilli(sliceStart).toString(),
                    "endedAt" to Instant.ofEpochMilli(sliceEnd).toString(),
                    "timezone" to timeZoneId,
                )
                sliceStart = sliceEnd
            }
        }
    }

    private fun shouldTrackPackage(packageName: String): Boolean {
        return packageName != this.packageName
    }

    private fun subtractUploadedIntervals(
        packageName: String,
        startedAtMillis: Long,
        endedAtMillis: Long,
    ): List<Pair<Long, Long>> {
        val intervals = RuleEnforcementStore.uploadedIntervalsForPackage(
            context = this,
            appId = packageName,
            startMillis = startedAtMillis,
            endMillis = endedAtMillis,
        ).sortedBy { it.startMillis }
        if (intervals.isEmpty()) {
            return listOf(startedAtMillis to endedAtMillis)
        }

        val remaining = mutableListOf<Pair<Long, Long>>()
        var cursor = startedAtMillis
        for (interval in intervals) {
            val intervalStart = maxOf(startedAtMillis, interval.startMillis)
            val intervalEnd = minOf(endedAtMillis, interval.endMillis)
            if (intervalStart > cursor) {
                remaining += cursor to intervalStart
            }
            cursor = maxOf(cursor, intervalEnd)
            if (cursor >= endedAtMillis) {
                break
            }
        }

        if (cursor < endedAtMillis) {
            remaining += cursor to endedAtMillis
        }

        return remaining.filter { (start, end) -> end > start }
    }

    private fun resolveAppMetadata(packageName: String): AppMetadata {
        val applicationInfo = getApplicationInfoOrNull(packageName)
        if (applicationInfo == null) {
            return AppMetadata(appName = packageName, category = null)
        }

        val appName = packageManager.getApplicationLabel(applicationInfo).toString().ifBlank {
            packageName
        }
        return AppMetadata(appName = appName, category = categoryNameFor(applicationInfo))
    }

    private fun getApplicationInfoOrNull(packageName: String): ApplicationInfo? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(
                    packageName,
                    android.content.pm.PackageManager.ApplicationInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, 0)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun categoryNameFor(applicationInfo: ApplicationInfo): String? {
        return when (applicationInfo.category) {
            ApplicationInfo.CATEGORY_GAME -> "Games"
            ApplicationInfo.CATEGORY_AUDIO,
            ApplicationInfo.CATEGORY_VIDEO,
            ApplicationInfo.CATEGORY_IMAGE,
            ApplicationInfo.CATEGORY_NEWS,
            ApplicationInfo.CATEGORY_SOCIAL,
            -> when (applicationInfo.category) {
                ApplicationInfo.CATEGORY_AUDIO,
                ApplicationInfo.CATEGORY_VIDEO,
                ApplicationInfo.CATEGORY_IMAGE,
                ApplicationInfo.CATEGORY_NEWS,
                -> "Entertainment"
                ApplicationInfo.CATEGORY_SOCIAL -> "Social"
                else -> null
            }
            ApplicationInfo.CATEGORY_PRODUCTIVITY -> "Productivity"
            ApplicationInfo.CATEGORY_MAPS -> "Navigation"
            ApplicationInfo.CATEGORY_UNDEFINED -> null
            else -> null
        }
    }

    companion object {
        private const val CHANNEL_NAME = "lockdin/usage"
        private const val DEFAULT_SYNC_DAYS = 14
        private const val MILLIS_PER_DAY = 24L * 60L * 60L * 1000L
        private const val MILLIS_PER_MINUTE = 60L * 1000L
    }
}

data class AppMetadata(
    val appName: String,
    val category: String?,
)
