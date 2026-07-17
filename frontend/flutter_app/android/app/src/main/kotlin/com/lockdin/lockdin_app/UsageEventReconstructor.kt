package com.lockdin.lockdin_app

data class UsageTimelineEvent(
    val packageName: String?,
    val className: String?,
    val eventType: Int,
    val timestampMillis: Long,
)

data class ReconstructedUsageSession(
    val packageName: String,
    val startedAtMillis: Long,
    val endedAtMillis: Long,
)

/**
 * Reconstructs a single foreground-app timeline from Android usage events.
 *
 * Android reports activity lifecycle events rather than complete sessions. This state machine
 * intentionally refuses to infer a start at the query boundary or an end at the query boundary.
 * Only a matching transition, another package becoming foreground, or an explicit device-state
 * boundary can close a session.
 */
class UsageEventReconstructor(
    private val excludedPackages: Set<String>,
    private val maximumSessionMillis: Long,
) {
    fun reconstruct(events: Iterable<UsageTimelineEvent>): List<ReconstructedUsageSession> {
        val sessions = mutableListOf<ReconstructedUsageSession>()
        val resumedActivities = mutableSetOf<String>()
        var activePackage: String? = null
        var activeStartedAt: Long? = null
        var deviceUsable = true

        fun closeActive(timestampMillis: Long) {
            val packageName = activePackage
            val startedAtMillis = activeStartedAt
            if (
                packageName != null &&
                startedAtMillis != null &&
                timestampMillis > startedAtMillis &&
                timestampMillis - startedAtMillis <= maximumSessionMillis
            ) {
                sessions += ReconstructedUsageSession(
                    packageName = packageName,
                    startedAtMillis = startedAtMillis,
                    endedAtMillis = timestampMillis,
                )
            }
            activePackage = null
            activeStartedAt = null
            resumedActivities.clear()
        }

        for (event in events.sortedBy { it.timestampMillis }) {
            when (event.eventType) {
                EVENT_SCREEN_NON_INTERACTIVE,
                EVENT_KEYGUARD_SHOWN,
                EVENT_DEVICE_SHUTDOWN,
                EVENT_DEVICE_STARTUP,
                -> {
                    closeActive(event.timestampMillis)
                    deviceUsable = false
                }

                EVENT_SCREEN_INTERACTIVE,
                EVENT_KEYGUARD_HIDDEN,
                -> deviceUsable = true

                EVENT_ACTIVITY_RESUMED -> {
                    val packageName = event.packageName?.takeIf { it.isNotBlank() } ?: continue
                    if (!deviceUsable || packageName in excludedPackages) {
                        closeActive(event.timestampMillis)
                        continue
                    }

                    if (activePackage != packageName) {
                        closeActive(event.timestampMillis)
                        activePackage = packageName
                        activeStartedAt = event.timestampMillis
                    }
                    resumedActivities += activityKey(event)
                }

                EVENT_ACTIVITY_PAUSED,
                EVENT_ACTIVITY_STOPPED,
                -> {
                    if (event.packageName != activePackage) {
                        continue
                    }

                    val key = activityKey(event)
                    if (event.className.isNullOrBlank()) {
                        closeActive(event.timestampMillis)
                    } else if (resumedActivities.remove(key) && resumedActivities.isEmpty()) {
                        closeActive(event.timestampMillis)
                    }
                }
            }
        }

        // An unmatched final resume is intentionally dropped. The caller cannot prove when it
        // ended, and extending it to the query end caused the original multi-day corruption.
        return sessions
    }

    private fun activityKey(event: UsageTimelineEvent): String =
        "${event.packageName.orEmpty()}|${event.className.orEmpty()}"

    companion object {
        // MOVE_TO_FOREGROUND/BACKGROUND share values with RESUMED/PAUSED on older Android.
        const val EVENT_ACTIVITY_RESUMED = 1
        const val EVENT_ACTIVITY_PAUSED = 2
        const val EVENT_SCREEN_INTERACTIVE = 15
        const val EVENT_SCREEN_NON_INTERACTIVE = 16
        const val EVENT_KEYGUARD_SHOWN = 17
        const val EVENT_KEYGUARD_HIDDEN = 18
        const val EVENT_ACTIVITY_STOPPED = 23
        const val EVENT_DEVICE_SHUTDOWN = 26
        const val EVENT_DEVICE_STARTUP = 27
    }
}
