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

data class UploadedUsageInterval(
    val startMillis: Long,
    val endMillis: Long,
)

fun subtractCoveredIntervals(
    startedAtMillis: Long,
    endedAtMillis: Long,
    coveredIntervals: Iterable<UploadedUsageInterval>,
): List<Pair<Long, Long>> {
    val remaining = mutableListOf<Pair<Long, Long>>()
    var cursor = startedAtMillis
    for (interval in coveredIntervals.sortedBy { it.startMillis }) {
        if (interval.endMillis <= startedAtMillis || interval.startMillis >= endedAtMillis) {
            continue
        }
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

/**
 * Reconstructs a single visible-app timeline from Android usage events.
 *
 * Android reports activity lifecycle events rather than complete sessions. This state machine
 * intentionally refuses to infer a start at the query boundary or an end at the query boundary.
 * A paused activity can remain visible in picture-in-picture or multi-window mode, so ownership
 * transfers only when the current activity is stopped (invisible) or at an explicit device-state
 * boundary. A newly resumed package waits as the next owner to keep the timeline non-overlapping.
 */
class UsageEventReconstructor(
    private val excludedPackages: Set<String>,
    private val maximumSessionMillis: Long,
) {
    fun reconstruct(events: Iterable<UsageTimelineEvent>): List<ReconstructedUsageSession> {
        val sessions = mutableListOf<ReconstructedUsageSession>()
        val activeVisibleActivities = mutableSetOf<String>()
        val pendingVisibleActivities = mutableSetOf<String>()
        var activePackage: String? = null
        var activeStartedAt: Long? = null
        var pendingPackage: String? = null
        var deviceUsable = true

        fun clearPending() {
            pendingPackage = null
            pendingVisibleActivities.clear()
        }

        fun closeActive(timestampMillis: Long, promotePending: Boolean = true) {
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
            activeVisibleActivities.clear()

            val nextPackage = pendingPackage
            if (
                promotePending &&
                deviceUsable &&
                nextPackage != null &&
                nextPackage !in excludedPackages &&
                pendingVisibleActivities.isNotEmpty()
            ) {
                activePackage = nextPackage
                activeStartedAt = timestampMillis
                activeVisibleActivities += pendingVisibleActivities
            }
            clearPending()
        }

        for (event in events.sortedBy { it.timestampMillis }) {
            when (event.eventType) {
                EVENT_SCREEN_NON_INTERACTIVE,
                EVENT_KEYGUARD_SHOWN,
                EVENT_DEVICE_SHUTDOWN,
                EVENT_DEVICE_STARTUP,
                -> {
                    closeActive(event.timestampMillis, promotePending = false)
                    deviceUsable = false
                }

                EVENT_SCREEN_INTERACTIVE,
                EVENT_KEYGUARD_HIDDEN,
                -> deviceUsable = true

                EVENT_ACTIVITY_RESUMED -> {
                    val packageName = event.packageName?.takeIf { it.isNotBlank() } ?: continue
                    if (!deviceUsable || packageName in excludedPackages) {
                        clearPending()
                        continue
                    }

                    if (activePackage == null) {
                        activePackage = packageName
                        activeStartedAt = event.timestampMillis
                        activeVisibleActivities += activityKey(event)
                    } else if (activePackage == packageName) {
                        clearPending()
                        activeVisibleActivities += activityKey(event)
                    } else {
                        if (pendingPackage != packageName) {
                            clearPending()
                            pendingPackage = packageName
                        }
                        pendingVisibleActivities += activityKey(event)
                    }
                }

                EVENT_ACTIVITY_PAUSED -> Unit

                EVENT_ACTIVITY_STOPPED -> {
                    when (event.packageName) {
                        activePackage -> {
                            if (event.className.isNullOrBlank()) {
                                closeActive(event.timestampMillis)
                            } else if (
                                activeVisibleActivities.remove(activityKey(event)) &&
                                activeVisibleActivities.isEmpty()
                            ) {
                                closeActive(event.timestampMillis)
                            }
                        }

                        pendingPackage -> {
                            if (event.className.isNullOrBlank()) {
                                clearPending()
                            } else if (
                                pendingVisibleActivities.remove(activityKey(event)) &&
                                pendingVisibleActivities.isEmpty()
                            ) {
                                clearPending()
                            }
                        }
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
