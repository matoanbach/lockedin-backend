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
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPermissionStatus" -> result.success(getPermissionStatus())
                "sendTestWarningNotification" -> {
                    result.success(NativeWarningNotifier.showTestWarning(this))
                }
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
                "cacheNotificationTone" -> {
                    val tone = call.argument<String>("tone")
                    if (!tone.isNullOrBlank()) {
                        RuleEnforcementStore.cacheNotificationTone(this, tone)
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
                "consumePendingEnforcementEvents" -> {
                    result.success(RuleEnforcementStore.consumePendingEnforcementEvents(this))
                }
                "consumePendingLaunchNavigation" -> {
                    result.success(consumePendingLaunchNavigation())
                }
                "collectUsageEventBatch" -> {
                    if (!hasUsageAccess()) {
                        result.error(
                            "usage_access_denied",
                            "Usage Access has not been granted.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    val queryStartMillis = call.argument<Number>("queryStartMillis")?.toLong()
                        ?: (System.currentTimeMillis() - MAX_QUERY_WINDOW_MILLIS)
                    val queryEndMillis = call.argument<Number>("queryEndMillis")?.toLong()
                        ?: System.currentTimeMillis()
                    val afterEndedAtMillis = call.argument<Number>("afterEndedAtMillis")?.toLong()
                    val afterSourceEventId = call.argument<String>("afterSourceEventId")
                    result.success(
                        collectUsageEventBatch(
                            requestedStartMillis = queryStartMillis,
                            requestedEndMillis = queryEndMillis,
                            afterEndedAtMillis = afterEndedAtMillis,
                            afterSourceEventId = afterSourceEventId,
                        ),
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getPermissionStatus(): Map<String, Any> {
        return mapOf(
            "usageAccess" to hasUsageAccess(),
            "notifications" to NotificationManagerCompat.from(this).areNotificationsEnabled(),
            "accessibility" to RuleEnforcementStore.isAccessibilityServiceEnabled(this),
            "notificationDiagnostics" to NativeWarningNotifier.diagnostics(this),
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

    private fun consumePendingLaunchNavigation(): Map<String, String>? {
        val route = intent?.getStringExtra(NativeWarningNotifier.EXTRA_LAUNCH_ROUTE) ?: return null
        intent?.removeExtra(NativeWarningNotifier.EXTRA_LAUNCH_ROUTE)
        return mapOf("route" to route)
    }

    private fun collectUsageEventBatch(
        requestedStartMillis: Long,
        requestedEndMillis: Long,
        afterEndedAtMillis: Long?,
        afterSourceEventId: String?,
    ): Map<String, Any?> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val nowMillis = System.currentTimeMillis()
        val endTimeMillis = requestedEndMillis.coerceIn(0L, nowMillis)
        val startTimeMillis = requestedStartMillis.coerceAtLeast(
            endTimeMillis - MAX_QUERY_WINDOW_MILLIS,
        ).coerceAtMost(endTimeMillis)
        val reconstructionStartMillis = (startTimeMillis - MAX_SESSION_MILLIS).coerceAtLeast(
            endTimeMillis - MAX_QUERY_WINDOW_MILLIS,
        )
        val events = usageStatsManager.queryEvents(reconstructionStartMillis, endTimeMillis)
        val event = UsageEvents.Event()
        val timelineEvents = mutableListOf<UsageTimelineEvent>()
        val timeZoneId = ZoneId.systemDefault().id

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            timelineEvents += UsageTimelineEvent(
                packageName = event.packageName,
                className = event.className,
                eventType = event.eventType,
                timestampMillis = event.timeStamp,
            )
        }

        val reconstructed = UsageEventReconstructor(
            excludedPackages = setOf(packageName),
            maximumSessionMillis = MAX_SESSION_MILLIS,
        ).reconstruct(timelineEvents)
        val payloads = mutableListOf<UsageSessionPayload>()
        for (session in reconstructed) {
            val clippedStart = maxOf(session.startedAtMillis, startTimeMillis)
            if (session.endedAtMillis <= clippedStart) {
                continue
            }
            for ((segmentStart, segmentEnd) in subtractUploadedIntervals(
                session.packageName,
                clippedStart,
                session.endedAtMillis,
            )) {
                val metadata = resolveAppMetadata(session.packageName)
                payloads += UsageSessionPayload(
                    sourceEventId = "android-usage:${session.packageName}:$segmentStart:$segmentEnd",
                    packageName = session.packageName,
                    appName = metadata.appName,
                    category = metadata.category,
                    startedAtMillis = segmentStart,
                    endedAtMillis = segmentEnd,
                    timezone = timeZoneId,
                )
            }
        }

        val sortedPayloads = payloads.sortedWith(
            compareBy<UsageSessionPayload> { it.endedAtMillis }.thenBy { it.sourceEventId },
        )
        val remaining = sortedPayloads.filter { payload ->
            when {
                afterEndedAtMillis == null -> true
                payload.endedAtMillis > afterEndedAtMillis -> true
                payload.endedAtMillis < afterEndedAtMillis -> false
                else -> payload.sourceEventId > afterSourceEventId.orEmpty()
            }
        }
        val page = remaining.take(MAX_SESSIONS_PER_BATCH)
        val last = page.lastOrNull()
        return mapOf(
            "events" to page.map(UsageSessionPayload::toChannelMap),
            "hasMore" to (remaining.size > page.size),
            "nextEndedAtMillis" to last?.endedAtMillis,
            "nextSourceEventId" to last?.sourceEventId,
            "queryStartMillis" to startTimeMillis,
            "queryEndMillis" to endTimeMillis,
        )
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
        private const val MAX_QUERY_WINDOW_MILLIS = 3L * 24L * 60L * 60L * 1000L
        private const val MAX_SESSION_MILLIS = 6L * 60L * 60L * 1000L
        private const val MAX_SESSIONS_PER_BATCH = 100
    }
}

data class UsageSessionPayload(
    val sourceEventId: String,
    val packageName: String,
    val appName: String,
    val category: String?,
    val startedAtMillis: Long,
    val endedAtMillis: Long,
    val timezone: String,
) {
    fun toChannelMap(): Map<String, Any?> = mapOf(
        "sourceEventId" to sourceEventId,
        "appId" to packageName,
        "appName" to appName,
        "category" to category,
        "startedAt" to Instant.ofEpochMilli(startedAtMillis).toString(),
        "endedAt" to Instant.ofEpochMilli(endedAtMillis).toString(),
        "timezone" to timezone,
    )
}

data class AppMetadata(
    val appName: String,
    val category: String?,
)
