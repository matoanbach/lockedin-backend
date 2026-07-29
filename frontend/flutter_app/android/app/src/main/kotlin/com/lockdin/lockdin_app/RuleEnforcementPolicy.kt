package com.lockdin.lockdin_app

object RuleEnforcementPolicy {
    fun shouldIntervene(limitMinutes: Int, usedMinutes: Int): Boolean {
        return limitMinutes > 0 && usedMinutes >= limitMinutes
    }

    fun warningEventType(limitMinutes: Int, usedMinutes: Int): String? {
        if (limitMinutes <= 0 || usedMinutes < 0) {
            return null
        }
        if (shouldIntervene(limitMinutes, usedMinutes)) {
            return "warning_limit_reached"
        }
        if (usedMinutes.toLong() * 5L >= limitMinutes.toLong() * 4L) {
            return "warning_approaching_limit"
        }
        return null
    }
}
