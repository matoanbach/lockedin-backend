package com.lockdin.lockdin_app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PictureInPictureInterventionPolicyTest {
    @Test
    fun matchesOnlyTheLimitedAppsPictureInPictureWindow() {
        assertTrue(
            PictureInPictureInterventionPolicy.matchesTargetWindow(
                targetPackageName = YOUTUBE,
                windowPackageName = YOUTUBE,
                isInPictureInPictureMode = true,
            ),
        )
        assertFalse(
            PictureInPictureInterventionPolicy.matchesTargetWindow(
                targetPackageName = YOUTUBE,
                windowPackageName = YOUTUBE,
                isInPictureInPictureMode = false,
            ),
        )
        assertFalse(
            PictureInPictureInterventionPolicy.matchesTargetWindow(
                targetPackageName = YOUTUBE,
                windowPackageName = "com.example.unrelated",
                isInPictureInPictureMode = true,
            ),
        )
        assertFalse(
            PictureInPictureInterventionPolicy.matchesTargetWindow(
                targetPackageName = YOUTUBE,
                windowPackageName = null,
                isInPictureInPictureMode = true,
            ),
        )
    }

    @Test
    fun retriesAreBounded() {
        assertTrue(PictureInPictureInterventionPolicy.shouldRetry(attempt = 0))
        assertTrue(PictureInPictureInterventionPolicy.shouldRetry(attempt = 4))
        assertFalse(PictureInPictureInterventionPolicy.shouldRetry(attempt = 5))
    }

    companion object {
        private const val YOUTUBE = "com.google.android.youtube"
    }
}
