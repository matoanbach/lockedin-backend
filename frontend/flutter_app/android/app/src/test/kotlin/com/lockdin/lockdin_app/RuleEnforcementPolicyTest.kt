package com.lockdin.lockdin_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RuleEnforcementPolicyTest {
    @Test
    fun approachingWarningUsesExactEightyPercentBoundary() {
        assertNull(RuleEnforcementPolicy.warningEventType(limitMinutes = 10, usedMinutes = 7))
        assertEquals(
            "warning_approaching_limit",
            RuleEnforcementPolicy.warningEventType(limitMinutes = 10, usedMinutes = 8),
        )
    }

    @Test
    fun approachingWarningDoesNotRoundSmallLimitsDown() {
        assertNull(RuleEnforcementPolicy.warningEventType(limitMinutes = 3, usedMinutes = 2))
        assertNull(RuleEnforcementPolicy.warningEventType(limitMinutes = 8, usedMinutes = 6))
        assertEquals(
            "warning_approaching_limit",
            RuleEnforcementPolicy.warningEventType(limitMinutes = 8, usedMinutes = 7),
        )
    }

    @Test
    fun exactLimitWarnsAndIntervenes() {
        assertEquals(
            "warning_limit_reached",
            RuleEnforcementPolicy.warningEventType(limitMinutes = 5, usedMinutes = 5),
        )
        assertTrue(RuleEnforcementPolicy.shouldIntervene(limitMinutes = 5, usedMinutes = 5))
    }

    @Test
    fun overLimitWarnsAndIntervenes() {
        assertEquals(
            "warning_limit_reached",
            RuleEnforcementPolicy.warningEventType(limitMinutes = 5, usedMinutes = 6),
        )
        assertTrue(RuleEnforcementPolicy.shouldIntervene(limitMinutes = 5, usedMinutes = 6))
    }

    @Test
    fun invalidLimitsDoNotWarnOrIntervene() {
        assertNull(RuleEnforcementPolicy.warningEventType(limitMinutes = 0, usedMinutes = 0))
        assertNull(RuleEnforcementPolicy.warningEventType(limitMinutes = 5, usedMinutes = -1))
        assertFalse(RuleEnforcementPolicy.shouldIntervene(limitMinutes = 0, usedMinutes = 0))
    }
}
