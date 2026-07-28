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

    fun liveUsedMinutes(
        baseMinutes: Int,
        localMillis: Long,
        currentSessionMillis: Long,
    ): Int {
        val nonNegativeBase = baseMinutes.coerceAtLeast(0)
        val accumulatedMillis =
            localMillis.coerceAtLeast(0L) + currentSessionMillis.coerceAtLeast(0L)
        return nonNegativeBase + (accumulatedMillis / MINUTE_MILLIS).toInt()
    }

    fun reconcileLocalUsageMillis(
        localUsageDate: String,
        localUsageMillis: Long,
        previousBackendUsageDate: String?,
        previousBackendUsedMinutes: Int?,
        refreshedBackendUsageDate: String,
        refreshedBackendUsedMinutes: Int,
        currentUsageDate: String,
    ): Long {
        if (localUsageDate != currentUsageDate) {
            return 0L
        }

        val retainedLocalMillis = localUsageMillis.coerceAtLeast(0L)
        if (refreshedBackendUsageDate != currentUsageDate) {
            return retainedLocalMillis
        }

        val previousBaseMinutes = if (previousBackendUsageDate == currentUsageDate) {
            previousBackendUsedMinutes?.coerceAtLeast(0) ?: 0
        } else {
            0
        }
        val acknowledgedMinutes =
            (refreshedBackendUsedMinutes.coerceAtLeast(0) - previousBaseMinutes)
                .coerceAtLeast(0)
        val acknowledgedMillis = acknowledgedMinutes.toLong() * MINUTE_MILLIS
        return (retainedLocalMillis - acknowledgedMillis).coerceAtLeast(0L)
    }
}
