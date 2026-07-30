package com.lockdin.lockdin_app

object RuleEnforcementPolicy {
    private const val MINUTE_MILLIS = 60_000L

    fun shouldIntervene(limitMinutes: Int, usedMilliseconds: Long): Boolean {
        return limitMinutes > 0 &&
            usedMilliseconds >= limitMinutes.toLong() * MINUTE_MILLIS
    }

    fun warningEventType(limitMinutes: Int, usedMilliseconds: Long): String? {
        if (limitMinutes <= 0 || usedMilliseconds < 0L) {
            return null
        }
        if (shouldIntervene(limitMinutes, usedMilliseconds)) {
            return "warning_limit_reached"
        }
        val limitMilliseconds = limitMinutes.toLong() * MINUTE_MILLIS
        if (usedMilliseconds * 5L >= limitMilliseconds * 4L) {
            return "warning_approaching_limit"
        }
        return null
    }
}
