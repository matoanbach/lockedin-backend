package com.lockdin.lockdin_app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UsagePackagePolicyTest {
    @Test
    fun `known launchers are excluded case-insensitively`() {
        assertTrue(UsagePackagePolicy.isKnownLauncherPackage("com.sec.android.app.launcher"))
        assertTrue(
            UsagePackagePolicy.isKnownLauncherPackage(
                " COM.GOOGLE.ANDROID.APPS.NEXUSLAUNCHER ",
            ),
        )
    }

    @Test
    fun `ordinary launchable apps are not treated as home launchers`() {
        assertFalse(UsagePackagePolicy.isKnownLauncherPackage("com.android.vending"))
        assertFalse(UsagePackagePolicy.isKnownLauncherPackage("com.spotify.music"))
    }
}
