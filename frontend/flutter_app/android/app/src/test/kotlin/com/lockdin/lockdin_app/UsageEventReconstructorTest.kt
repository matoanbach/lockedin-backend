package com.lockdin.lockdin_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class UsageEventReconstructorTest {
    private val reconstructor = UsageEventReconstructor(
        excludedPackages = setOf(LOCKDIN),
        maximumSessionMillis = SIX_HOURS,
    )

    @Test
    fun reconstructsMeasuredNinetyFiveSecondSession() {
        val sessions = reconstructor.reconstruct(
            listOf(
                event(YOUTUBE, "WatchActivity", RESUMED, 1_000),
                event(YOUTUBE, "WatchActivity", PAUSED, 96_000),
            ),
        )

        assertEquals(
            listOf(ReconstructedUsageSession(YOUTUBE, 1_000, 96_000)),
            sessions,
        )
    }

    @Test
    fun repeatedResumeAndMultipleActivitiesDoNotResetPackageStart() {
        val sessions = reconstructor.reconstruct(
            listOf(
                event(YOUTUBE, "HomeActivity", RESUMED, 1_000),
                event(YOUTUBE, "HomeActivity", RESUMED, 2_000),
                event(YOUTUBE, "WatchActivity", RESUMED, 3_000),
                event(YOUTUBE, "HomeActivity", PAUSED, 4_000),
                event(YOUTUBE, "WatchActivity", PAUSED, 8_000),
            ),
        )

        assertEquals(
            listOf(ReconstructedUsageSession(YOUTUBE, 1_000, 8_000)),
            sessions,
        )
    }

    @Test
    fun anotherPackageResumeClosesPreviousTimeline() {
        val sessions = reconstructor.reconstruct(
            listOf(
                event(YOUTUBE, "WatchActivity", RESUMED, 1_000),
                event(INSTAGRAM, "MainActivity", RESUMED, 5_000),
                event(YOUTUBE, "WatchActivity", PAUSED, 6_000),
                event(INSTAGRAM, "MainActivity", PAUSED, 9_000),
            ),
        )

        assertEquals(
            listOf(
                ReconstructedUsageSession(YOUTUBE, 1_000, 5_000),
                ReconstructedUsageSession(INSTAGRAM, 5_000, 9_000),
            ),
            sessions,
        )
    }

    @Test
    fun lockdinResumeClosesTrackedAppWithoutTrackingItself() {
        val sessions = reconstructor.reconstruct(
            listOf(
                event(YOUTUBE, "WatchActivity", RESUMED, 1_000),
                event(LOCKDIN, "MainActivity", RESUMED, 5_000),
            ),
        )

        assertEquals(
            listOf(ReconstructedUsageSession(YOUTUBE, 1_000, 5_000)),
            sessions,
        )
    }

    @Test
    fun unmatchedBoundaryEventsAreNeverExtendedOrInvented() {
        val sessions = reconstructor.reconstruct(
            listOf(
                event(YOUTUBE, "WatchActivity", PAUSED, 1_000),
                event(YOUTUBE, "WatchActivity", RESUMED, 2_000),
            ),
        )

        assertTrue(sessions.isEmpty())
    }

    @Test
    fun screenOffAndShutdownCloseSessions() {
        val sessions = reconstructor.reconstruct(
            listOf(
                event(YOUTUBE, "WatchActivity", RESUMED, 1_000),
                deviceEvent(SCREEN_OFF, 5_000),
                deviceEvent(SCREEN_ON, 6_000),
                event(INSTAGRAM, "MainActivity", RESUMED, 7_000),
                deviceEvent(SHUTDOWN, 10_000),
            ),
        )

        assertEquals(
            listOf(
                ReconstructedUsageSession(YOUTUBE, 1_000, 5_000),
                ReconstructedUsageSession(INSTAGRAM, 7_000, 10_000),
            ),
            sessions,
        )
    }

    @Test
    fun implausiblyLongMatchedSessionIsDropped() {
        val sessions = reconstructor.reconstruct(
            listOf(
                event(YOUTUBE, "WatchActivity", RESUMED, 1_000),
                event(YOUTUBE, "WatchActivity", PAUSED, 1_000 + SIX_HOURS + 1),
            ),
        )

        assertTrue(sessions.isEmpty())
    }

    private fun event(
        packageName: String,
        className: String,
        type: Int,
        timestamp: Long,
    ) = UsageTimelineEvent(packageName, className, type, timestamp)

    private fun deviceEvent(type: Int, timestamp: Long) =
        UsageTimelineEvent(null, null, type, timestamp)

    companion object {
        private const val YOUTUBE = "com.google.android.youtube"
        private const val INSTAGRAM = "com.instagram.android"
        private const val LOCKDIN = "com.lockdin.lockdin_app"
        private const val SIX_HOURS = 6L * 60L * 60L * 1000L
        private const val RESUMED = UsageEventReconstructor.EVENT_ACTIVITY_RESUMED
        private const val PAUSED = UsageEventReconstructor.EVENT_ACTIVITY_PAUSED
        private const val SCREEN_ON = UsageEventReconstructor.EVENT_SCREEN_INTERACTIVE
        private const val SCREEN_OFF = UsageEventReconstructor.EVENT_SCREEN_NON_INTERACTIVE
        private const val SHUTDOWN = UsageEventReconstructor.EVENT_DEVICE_SHUTDOWN
    }
}
