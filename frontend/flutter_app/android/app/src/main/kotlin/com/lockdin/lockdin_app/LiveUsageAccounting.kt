package com.lockdin.lockdin_app

data class UsagePersistenceUpdate(
    val deltaMillis: Long,
    val persistedUntilMillis: Long,
)

object LiveUsageAccounting {
    private const val MINUTE_MILLIS = 60_000L

    fun persistenceUpdate(
        persistedUntilMillis: Long,
        nowMillis: Long,
    ): UsagePersistenceUpdate {
        val boundedNowMillis = maxOf(persistedUntilMillis, nowMillis)
        return UsagePersistenceUpdate(
            deltaMillis = boundedNowMillis - persistedUntilMillis,
            persistedUntilMillis = boundedNowMillis,
        )
    }

    fun liveUsedMilliseconds(
        baseMilliseconds: Long,
        localMillis: Long,
        currentSessionMillis: Long,
    ): Long {
        val nonNegativeBase = baseMilliseconds.coerceAtLeast(0L)
        val accumulatedMillis =
            localMillis.coerceAtLeast(0L) + currentSessionMillis.coerceAtLeast(0L)
        return nonNegativeBase + accumulatedMillis
    }

    fun completedMinutes(milliseconds: Long): Int =
        (milliseconds.coerceAtLeast(0L) / MINUTE_MILLIS).toInt()

    fun reconcileLocalUsageMillis(
        localUsageDate: String,
        localUsageMillis: Long,
        previousBackendUsageDate: String?,
        previousBackendUsedMilliseconds: Long?,
        refreshedBackendUsageDate: String,
        refreshedBackendUsedMilliseconds: Long,
        currentUsageDate: String,
    ): Long {
        if (localUsageDate != currentUsageDate) {
            return 0L
        }

        val retainedLocalMillis = localUsageMillis.coerceAtLeast(0L)
        if (refreshedBackendUsageDate != currentUsageDate) {
            return retainedLocalMillis
        }

        val previousBaseMilliseconds = if (previousBackendUsageDate == currentUsageDate) {
            previousBackendUsedMilliseconds?.coerceAtLeast(0L) ?: 0L
        } else {
            0L
        }
        val acknowledgedMilliseconds =
            (
                refreshedBackendUsedMilliseconds.coerceAtLeast(0L) -
                    previousBaseMilliseconds
            ).coerceAtLeast(0L)
        return (retainedLocalMillis - acknowledgedMilliseconds).coerceAtLeast(0L)
    }
}
