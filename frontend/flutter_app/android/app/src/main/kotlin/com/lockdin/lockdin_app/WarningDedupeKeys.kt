package com.lockdin.lockdin_app

object WarningDedupeKeys {
    fun native(
        ruleId: String,
        usageDate: String,
        eventType: String,
        ownerGeneration: String = QueueOwnershipPolicy.UNCLAIMED_OWNER,
    ): String = "$ownerGeneration|$usageDate|$ruleId|$eventType"

    fun flutter(
        ruleId: String,
        usageDate: String,
        eventType: String,
        ownerGeneration: String = QueueOwnershipPolicy.UNCLAIMED_OWNER,
    ): String = "flutter.rule_alert.$ownerGeneration.$ruleId.$usageDate.$eventType"

    fun flutterFromNative(nativeKey: String): String? {
        val parts = nativeKey.split('|', limit = 4)
        if (parts.size != 4 || parts.any(String::isBlank)) {
            return null
        }

        val (ownerGeneration, usageDate, ruleId, eventType) = parts
        if (eventType != "warning_approaching_limit" &&
            eventType != "warning_limit_reached"
        ) {
            return null
        }
        return flutter(ruleId, usageDate, eventType, ownerGeneration)
    }
}
