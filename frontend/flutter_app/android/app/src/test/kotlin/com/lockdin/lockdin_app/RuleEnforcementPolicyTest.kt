package com.lockdin.lockdin_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RuleEnforcementPolicyTest {
    @Test
    fun approachingWarningUsesExactEightyPercentBoundary() {
        assertNull(
            RuleEnforcementPolicy.warningEventType(
                limitMinutes = 10,
                usedMilliseconds = minutes(8) - 1L,
            ),
        )
        assertEquals(
            "warning_approaching_limit",
            RuleEnforcementPolicy.warningEventType(
                limitMinutes = 10,
                usedMilliseconds = minutes(8),
            ),
        )
    }

    @Test
    fun approachingWarningDoesNotRoundSmallLimitsDown() {
        val exactBoundary = minutes(8) * 4L / 5L
        assertNull(
            RuleEnforcementPolicy.warningEventType(
                limitMinutes = 8,
                usedMilliseconds = exactBoundary - 1L,
            ),
        )
        assertEquals(
            "warning_approaching_limit",
            RuleEnforcementPolicy.warningEventType(
                limitMinutes = 8,
                usedMilliseconds = exactBoundary,
            ),
        )
    }

    @Test
    fun exactLimitWarnsAndIntervenes() {
        assertEquals(
            "warning_limit_reached",
            RuleEnforcementPolicy.warningEventType(
                limitMinutes = 5,
                usedMilliseconds = minutes(5),
            ),
        )
        assertTrue(
            RuleEnforcementPolicy.shouldIntervene(
                limitMinutes = 5,
                usedMilliseconds = minutes(5),
            ),
        )
    }

    @Test
    fun overLimitWarnsAndIntervenes() {
        assertEquals(
            "warning_limit_reached",
            RuleEnforcementPolicy.warningEventType(
                limitMinutes = 5,
                usedMilliseconds = 300_100L,
            ),
        )
        assertTrue(
            RuleEnforcementPolicy.shouldIntervene(
                limitMinutes = 5,
                usedMilliseconds = 300_100L,
            ),
        )
    }

    @Test
    fun invalidLimitsDoNotWarnOrIntervene() {
        assertNull(
            RuleEnforcementPolicy.warningEventType(
                limitMinutes = 0,
                usedMilliseconds = 0L,
            ),
        )
        assertNull(
            RuleEnforcementPolicy.warningEventType(
                limitMinutes = 5,
                usedMilliseconds = -1L,
            ),
        )
        assertFalse(
            RuleEnforcementPolicy.shouldIntervene(
                limitMinutes = 0,
                usedMilliseconds = 0L,
            ),
        )
    }

    @Test
    fun approvedFiveMinuteBoundaryCasesUseExactMilliseconds() {
        assertFalse(
            RuleEnforcementPolicy.shouldIntervene(
                limitMinutes = 5,
                usedMilliseconds = 299_900L,
            ),
        )
        for (usedMilliseconds in listOf(300_000L, 300_100L, 315_400L, 359_900L)) {
            assertTrue(
                RuleEnforcementPolicy.shouldIntervene(
                    limitMinutes = 5,
                    usedMilliseconds = usedMilliseconds,
                ),
            )
            assertEquals(
                "warning_limit_reached",
                RuleEnforcementPolicy.warningEventType(
                    limitMinutes = 5,
                    usedMilliseconds = usedMilliseconds,
                ),
            )
        }
    }

    private fun minutes(value: Long): Long = value * 60_000L
}
