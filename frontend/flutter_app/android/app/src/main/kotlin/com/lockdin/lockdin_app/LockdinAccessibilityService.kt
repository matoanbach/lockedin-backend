package com.lockdin.lockdin_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import java.time.Instant
import java.time.ZoneId
import kotlin.math.absoluteValue
import kotlin.math.roundToInt

class LockdinAccessibilityService : AccessibilityService() {
    private val tag = "LockdInAccessibility"
    private val monitorHandler = Handler(Looper.getMainLooper())
    private val monitorRunnable = object : Runnable {
        override fun run() {
            val shouldContinue = evaluateActivePackage()
            if (shouldContinue) {
                monitorHandler.postDelayed(this, MONITOR_INTERVAL_MILLIS)
            }
        }
    }

    private var activePackageName: String? = null
    private var activePackageAppName: String = ""
    private var activePackageCategory: String? = null
    private var activePackageStartedAtMillis: Long? = null
    private var activePackageUploadedUntilMillis: Long? = null
    private var isMonitoring = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(tag, "Accessibility service connected")
        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOWS_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 100
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !isRelevantEvent(event.eventType)) {
            return
        }

        val packageName = event.packageName?.toString()?.takeIf { it.isNotBlank() } ?: return
        Log.d(tag, "Foreground accessibility event for package=$packageName type=${event.eventType}")
        handleForegroundPackage(packageName)
    }

    override fun onInterrupt() {
        finalizeActivePackageSession()
    }

    override fun onDestroy() {
        finalizeActivePackageSession()
        super.onDestroy()
    }

    private fun handleForegroundPackage(packageName: String) {
        if (activePackageName != null && activePackageName != packageName) {
            finalizeActivePackageSession()
        }

        if (activePackageName != packageName) {
            val metadata = resolveAppMetadata(packageName)
            val startedAtMillis = System.currentTimeMillis()
            Log.d(tag, "Tracking package=$packageName appName=${metadata.appName}")
            activePackageName = packageName
            activePackageAppName = metadata.appName
            activePackageCategory = metadata.category
            activePackageStartedAtMillis = startedAtMillis
            activePackageUploadedUntilMillis = startedAtMillis
        }

        if (packageName != activePackageName) {
            return
        }

        if (packageName == this.packageName) {
            finalizeActivePackageSession()
            RuleEnforcementStore.clearInterventionCooldown(this)
            return
        }

        evaluateActivePackage(forceUploadPartialSlice = false)
        startMonitoring()
    }

    private fun evaluateActivePackage(forceUploadPartialSlice: Boolean = false): Boolean {
        val packageName = activePackageName ?: return false
        if (packageName == this.packageName) {
            return false
        }

        val sessionStart = activePackageStartedAtMillis ?: return false
        val nowMillis = System.currentTimeMillis()
        flushUsageSlices(nowMillis, forceUploadPartialSlice)

        val rule = RuleEnforcementStore.findRuleForPackage(this, packageName) ?: run {
            Log.d(tag, "No cached rule match for package=$packageName")
            return true
        }
        val elapsedMillis = (nowMillis - sessionStart).coerceAtLeast(0L)
        val liveUsedMinutes = RuleEnforcementStore.calculateLiveUsedMinutes(this, rule, elapsedMillis)
        Log.d(
            tag,
            "Evaluated package=$packageName rule=${rule.ruleId} used=$liveUsedMinutes limit=${rule.limitMinutes}",
        )

        maybeIssueNativeWarning(rule, liveUsedMinutes)

        if (liveUsedMinutes <= rule.limitMinutes) {
            return true
        }

        if (RuleEnforcementStore.wasRecentlyIntervened(
                context = this,
                packageName = packageName,
                cooldownMillis = INTERVENTION_COOLDOWN_MILLIS,
                timestampMillis = System.currentTimeMillis(),
            )
        ) {
            Log.d(tag, "Skipping intervention due to cooldown for package=$packageName")
            return false
        }

        flushUsageSlices(nowMillis, forcePartial = true)
        persistActivePackageUsage(elapsedMillis)
        RuleEnforcementStore.markIntervened(this, packageName, System.currentTimeMillis())
        RuleEnforcementStore.queuePendingIntervention(
            context = this,
            pending = PendingIntervention(
                ruleId = rule.ruleId,
                appId = rule.appId,
                appName = rule.appName,
                usageDate = RuleEnforcementStore.currentUsageDate(),
                usedMinutes = liveUsedMinutes,
                limitMinutes = rule.limitMinutes,
                status = if (liveUsedMinutes > rule.limitMinutes) "over_limit" else "at_limit",
                source = "android_accessibility",
            ),
        )

        performGlobalAction(GLOBAL_ACTION_HOME)
        launchLockdinIntervention()
        stopMonitoring()
        Log.d(tag, "Queued live intervention for package=$packageName used=$liveUsedMinutes")
        return false
    }

    private fun flushUsageSlices(nowMillis: Long, forcePartial: Boolean) {
        val packageName = activePackageName ?: return
        var uploadedUntil = activePackageUploadedUntilMillis ?: return
        val sessionStart = activePackageStartedAtMillis ?: return
        if (nowMillis <= uploadedUntil || uploadedUntil < sessionStart) {
            return
        }

        val boundedUploadStart = maxOf(uploadedUntil, nowMillis - MAX_UPLOAD_BACKFILL_MILLIS)
        if (boundedUploadStart != uploadedUntil) {
            uploadedUntil = boundedUploadStart
            activePackageUploadedUntilMillis = boundedUploadStart
        }

        val maxUploadEnd = if (forcePartial) {
            nowMillis
        } else {
            nowMillis - ((nowMillis - uploadedUntil) % MINUTE_MILLIS)
        }

        if (maxUploadEnd <= uploadedUntil) {
            return
        }

        var sliceStart = uploadedUntil
        var sliceCount = 0
        while (sliceStart < maxUploadEnd) {
            if (sliceCount >= MAX_SLICES_PER_FLUSH) {
                break
            }

            val currentSliceStart = sliceStart
            val currentSliceEnd = minOf(currentSliceStart + MINUTE_MILLIS, maxUploadEnd)
            val payload = UsageSlicePayload(
                sourceEventId = "android:$packageName:$currentSliceStart:$currentSliceEnd",
                appId = packageName,
                appName = activePackageAppName.ifBlank { packageName },
                category = activePackageCategory,
                startedAtMillis = currentSliceStart,
                endedAtMillis = currentSliceEnd,
                startedAtIso = Instant.ofEpochMilli(currentSliceStart).toString(),
                endedAtIso = Instant.ofEpochMilli(currentSliceEnd).toString(),
                timezone = ZoneId.systemDefault().id,
            )
            NativeUsageUploader.enqueueUsageSlice(context = this, slice = payload)
            sliceStart = currentSliceEnd
            sliceCount += 1
        }

        activePackageUploadedUntilMillis = sliceStart
    }

    private fun persistActivePackageUsage(elapsedMillis: Long) {
        val packageName = activePackageName ?: return
        val uploadedUntil = activePackageUploadedUntilMillis ?: return
        val sessionStart = activePackageStartedAtMillis ?: return
        val accountedMillis = (uploadedUntil - sessionStart).coerceAtLeast(0L)
        val unaccountedMillis = elapsedMillis - accountedMillis
        if (unaccountedMillis <= 0L) {
            return
        }

        RuleEnforcementStore.addLocalUsageMillis(
            context = this,
            appId = packageName,
            usageDate = RuleEnforcementStore.currentUsageDate(),
            durationMillis = unaccountedMillis,
        )
    }

    private fun finalizeActivePackageSession() {
        val sessionStart = activePackageStartedAtMillis
        if (sessionStart != null && activePackageName != null && activePackageName != this.packageName) {
            val elapsedMillis = (System.currentTimeMillis() - sessionStart).coerceAtLeast(0L)
            flushUsageSlices(System.currentTimeMillis(), forcePartial = true)
            persistActivePackageUsage(elapsedMillis)
        }

        activePackageName = null
        activePackageAppName = ""
        activePackageCategory = null
        activePackageStartedAtMillis = null
        activePackageUploadedUntilMillis = null
        stopMonitoring()
    }

    private fun startMonitoring() {
        if (isMonitoring) {
            return
        }

        isMonitoring = true
        monitorHandler.postDelayed(monitorRunnable, MONITOR_INTERVAL_MILLIS)
    }

    private fun stopMonitoring() {
        if (!isMonitoring) {
            return
        }

        isMonitoring = false
        monitorHandler.removeCallbacks(monitorRunnable)
    }

    private fun maybeIssueNativeWarning(rule: CachedRuleStatus, liveUsedMinutes: Int) {
        val eventType = warningEventType(rule.limitMinutes, liveUsedMinutes) ?: return
        val usageDate = RuleEnforcementStore.currentUsageDate()
        if (RuleEnforcementStore.hasIssuedWarning(this, rule.ruleId, usageDate, eventType)) {
            Log.d(tag, "Skipping $eventType warning for rule=${rule.ruleId} because it already fired today")
            return
        }

        val warning = warningContent(rule, liveUsedMinutes, eventType) ?: return
        val notificationShown = NativeWarningNotifier.showWarning(
            context = this,
            notificationId = (rule.ruleId.hashCode() * 31 + eventType.hashCode()).absoluteValue,
            title = warning.first,
            body = warning.second,
        )
        if (!notificationShown) {
            Log.w(tag, "Native warning notification was not shown for rule=${rule.ruleId} eventType=$eventType")
            return
        }

        RuleEnforcementStore.markWarningIssued(this, rule.ruleId, usageDate, eventType)
        Log.d(tag, "Issued $eventType warning for rule=${rule.ruleId} used=$liveUsedMinutes")
        RuleEnforcementStore.queuePendingEnforcementEvent(
            context = this,
            event = PendingEnforcementEvent(
                ruleId = rule.ruleId,
                appId = rule.appId,
                eventType = eventType,
                usageDate = usageDate,
                usedMinutes = liveUsedMinutes,
                limitMinutes = rule.limitMinutes,
                source = "android_accessibility",
            ),
        )
    }

    private fun warningEventType(limitMinutes: Int, liveUsedMinutes: Int): String? {
        if (liveUsedMinutes >= limitMinutes) {
            return "warning_limit_reached"
        }

        if (liveUsedMinutes >= (limitMinutes * 0.8).roundToInt()) {
            return "warning_approaching_limit"
        }

        return null
    }

    private fun warningContent(
        rule: CachedRuleStatus,
        liveUsedMinutes: Int,
        eventType: String,
    ): Pair<String, String>? {
        val tone = RuleEnforcementStore.notificationTone(this)
        return when (eventType) {
            "warning_approaching_limit" -> {
                val remainingMinutes = (rule.limitMinutes - liveUsedMinutes).coerceAtLeast(0)
                val title = "${rule.appName} is approaching its limit"
                val body = when (tone) {
                    "fun" -> "Heads up: only $remainingMinutes minutes left before ${rule.appName} hits today's limit."
                    "edgy" -> "$remainingMinutes minutes left. ${rule.appName} is almost out of runway."
                    else -> "$remainingMinutes minutes remain before you hit today's ${rule.limitMinutes}-minute limit for ${rule.appName}."
                }
                title to body
            }

            "warning_limit_reached" -> {
                val title = if (liveUsedMinutes > rule.limitMinutes) {
                    "${rule.appName} is over limit"
                } else {
                    "${rule.appName} reached its limit"
                }
                val body = when (tone) {
                    "fun" -> "You just hit today's ${rule.limitMinutes}-minute limit for ${rule.appName}. Time to step out for a reset."
                    "edgy" -> "Limit reached. Close ${rule.appName} before it steals more of your day."
                    else -> "You have hit today's ${rule.limitMinutes}-minute limit for ${rule.appName}."
                }
                title to body
            }

            else -> null
        }
    }

    private fun launchLockdinIntervention() {
        monitorHandler.postDelayed(
            {
                startActivity(
                    Intent(this, MainActivity::class.java).apply {
                        addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
                        )
                    },
                )
            },
            RETURN_TO_LOCKDIN_DELAY_MILLIS,
        )
    }

    private fun isRelevantEvent(eventType: Int): Boolean {
        return eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED
    }

    private fun resolveAppMetadata(packageName: String): AppMetadata {
        val applicationInfo = try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
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

        if (applicationInfo == null) {
            return AppMetadata(appName = packageName, category = null)
        }

        val appName = packageManager.getApplicationLabel(applicationInfo).toString().ifBlank {
            packageName
        }
        val category = when (applicationInfo.category) {
            android.content.pm.ApplicationInfo.CATEGORY_GAME -> "Games"
            android.content.pm.ApplicationInfo.CATEGORY_AUDIO,
            android.content.pm.ApplicationInfo.CATEGORY_VIDEO,
            android.content.pm.ApplicationInfo.CATEGORY_IMAGE,
            android.content.pm.ApplicationInfo.CATEGORY_NEWS,
            -> "Entertainment"
            android.content.pm.ApplicationInfo.CATEGORY_SOCIAL -> "Social"
            android.content.pm.ApplicationInfo.CATEGORY_PRODUCTIVITY -> "Productivity"
            android.content.pm.ApplicationInfo.CATEGORY_MAPS -> "Navigation"
            else -> null
        }
        return AppMetadata(appName = appName, category = category)
    }

    companion object {
        private const val MONITOR_INTERVAL_MILLIS = 15_000L
        private const val INTERVENTION_COOLDOWN_MILLIS = 2_000L
        private const val MINUTE_MILLIS = 60_000L
        private const val MAX_SLICES_PER_FLUSH = 15
        private const val MAX_UPLOAD_BACKFILL_MILLIS =
            MAX_SLICES_PER_FLUSH * MINUTE_MILLIS
        private const val RETURN_TO_LOCKDIN_DELAY_MILLIS = 150L
    }
}
