package com.lockdin.lockdin_app

object WarningDedupeKeys {
    fun native(
        ruleId: String,
        usageDate: String,
        eventType: String,
    ): String = "$usageDate|$ruleId|$eventType"

    fun flutter(
        ruleId: String,
        usageDate: String,
        eventType: String,
    ): String = "flutter.rule_alert.$ruleId.$usageDate.$eventType"

    fun flutterFromNative(nativeKey: String): String? {
        val parts = nativeKey.split('|', limit = 3)
        if (parts.size != 3 || parts.any(String::isBlank)) {
            return null
        }

        val (usageDate, ruleId, eventType) = parts
        if (eventType != "warning_approaching_limit" &&
            eventType != "warning_limit_reached"
        ) {
            return null
        }
        return flutter(ruleId, usageDate, eventType)
    }
}
