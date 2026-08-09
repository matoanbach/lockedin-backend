package com.lockdin.lockdin_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WarningDedupeKeysTest {
    @Test
    fun nativeLimitMarkerMapsToFlutterRuleAlertKey() {
        assertEquals(
            "flutter.rule_alert.account-a.rule-123.2026-07-27.warning_limit_reached",
            WarningDedupeKeys.flutterFromNative(
                WarningDedupeKeys.native(
                    ruleId = "rule-123",
                    usageDate = "2026-07-27",
                    eventType = "warning_limit_reached",
                    ownerGeneration = "account-a",
                ),
            ),
        )
    }

    @Test
    fun nativeApproachingMarkerMapsToFlutterRuleAlertKey() {
        assertEquals(
            "flutter.rule_alert.account-a.rule-123.2026-07-27.warning_approaching_limit",
            WarningDedupeKeys.flutterFromNative(
                "account-a|2026-07-27|rule-123|warning_approaching_limit",
            ),
        )
    }

    @Test
    fun malformedOrUnrelatedMarkersAreIgnored() {
        for (marker in listOf(
            "",
            "2026-07-27",
            "account-a|2026-07-27||warning_limit_reached",
            "account-a|2026-07-27|rule-123|intervention_blocked",
        )) {
            assertNull(WarningDedupeKeys.flutterFromNative(marker))
        }
    }
}
