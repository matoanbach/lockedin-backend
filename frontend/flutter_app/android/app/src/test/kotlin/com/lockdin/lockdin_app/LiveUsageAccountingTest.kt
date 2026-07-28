package com.lockdin.lockdin_app

import org.junit.Assert.assertEquals
import org.junit.Test

class LiveUsageAccountingTest {
    @Test
    fun interruptedSessionsAccumulateToTheLimit() {
        assertEquals(
            5,
            LiveUsageAccounting.liveUsedMinutes(
                baseMinutes = 0,
                localMillis = minutes(4) + seconds(5),
                currentSessionMillis = seconds(55),
            ),
        )
    }

    @Test
    fun continuedAccumulatedUsageReachesTheInterventionThreshold() {
        assertEquals(
            6,
            LiveUsageAccounting.liveUsedMinutes(
                baseMinutes = 0,
                localMillis = minutes(4) + seconds(5),
                currentSessionMillis = minutes(1) + seconds(55),
            ),
        )
    }

    @Test
    fun repeatedPersistenceTimestampsDoNotDoubleCount() {
        val first = LiveUsageAccounting.persistenceUpdate(
            persistedUntilMillis = 1_000L,
            nowMillis = 6_000L,
        )
        val repeated = LiveUsageAccounting.persistenceUpdate(
            persistedUntilMillis = first.persistedUntilMillis,
            nowMillis = 6_000L,
        )
        val continued = LiveUsageAccounting.persistenceUpdate(
            persistedUntilMillis = repeated.persistedUntilMillis,
            nowMillis = 8_500L,
        )

        assertEquals(5_000L, first.deltaMillis)
        assertEquals(0L, repeated.deltaMillis)
        assertEquals(2_500L, continued.deltaMillis)
        assertEquals(7_500L, first.deltaMillis + repeated.deltaMillis + continued.deltaMillis)
    }

    @Test
    fun backendAdvanceRemovesOnlyAcknowledgedWholeMinutes() {
        assertEquals(
            minutes(2) + seconds(5),
            reconcile(
                localMillis = minutes(4) + seconds(5),
                previousBaseMinutes = 3,
                refreshedBaseMinutes = 5,
            ),
        )
    }

    @Test
    fun backendAdvanceRetainsUnacknowledgedRemainder() {
        assertEquals(
            seconds(5),
            reconcile(
                localMillis = minutes(4) + seconds(5),
                previousBaseMinutes = 0,
                refreshedBaseMinutes = 4,
            ),
        )
    }

    @Test
    fun backendAdvanceClampsAtZero() {
        assertEquals(
            0L,
            reconcile(
                localMillis = seconds(30),
                previousBaseMinutes = 1,
                refreshedBaseMinutes = 3,
            ),
        )
    }

    @Test
    fun dateRolloverDoesNotRetainPriorDayUsage() {
        assertEquals(
            0L,
            LiveUsageAccounting.reconcileLocalUsageMillis(
                localUsageDate = "2026-07-26",
                localUsageMillis = minutes(4) + seconds(5),
                previousBackendUsageDate = "2026-07-26",
                previousBackendUsedMinutes = 4,
                refreshedBackendUsageDate = TODAY,
                refreshedBackendUsedMinutes = 0,
                currentUsageDate = TODAY,
            ),
        )
    }

    @Test
    fun staleBackendDateCannotEraseCurrentDayLocalUsage() {
        assertEquals(
            seconds(45),
            LiveUsageAccounting.reconcileLocalUsageMillis(
                localUsageDate = TODAY,
                localUsageMillis = seconds(45),
                previousBackendUsageDate = "2026-07-26",
                previousBackendUsedMinutes = 8,
                refreshedBackendUsageDate = "2026-07-26",
                refreshedBackendUsedMinutes = 8,
                currentUsageDate = TODAY,
            ),
        )
    }

    private fun reconcile(
        localMillis: Long,
        previousBaseMinutes: Int,
        refreshedBaseMinutes: Int,
    ): Long {
        return LiveUsageAccounting.reconcileLocalUsageMillis(
            localUsageDate = TODAY,
            localUsageMillis = localMillis,
            previousBackendUsageDate = TODAY,
            previousBackendUsedMinutes = previousBaseMinutes,
            refreshedBackendUsageDate = TODAY,
            refreshedBackendUsedMinutes = refreshedBaseMinutes,
            currentUsageDate = TODAY,
        )
    }

    private fun minutes(value: Long): Long = value * 60_000L

    private fun seconds(value: Long): Long = value * 1_000L

    companion object {
        private const val TODAY = "2026-07-27"
    }
}
