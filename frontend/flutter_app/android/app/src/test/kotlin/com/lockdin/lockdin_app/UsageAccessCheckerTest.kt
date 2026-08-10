package com.lockdin.lockdin_app

import android.app.AppOpsManager
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UsageAccessCheckerTest {
    @Test
    fun onlyAllowedAppOpGrantsUsageTrackingConsent() {
        assertTrue(UsageAccessChecker.isGrantedMode(AppOpsManager.MODE_ALLOWED))
        assertFalse(UsageAccessChecker.isGrantedMode(AppOpsManager.MODE_IGNORED))
        assertFalse(UsageAccessChecker.isGrantedMode(AppOpsManager.MODE_ERRORED))
        assertFalse(UsageAccessChecker.isGrantedMode(AppOpsManager.MODE_DEFAULT))
    }
}
