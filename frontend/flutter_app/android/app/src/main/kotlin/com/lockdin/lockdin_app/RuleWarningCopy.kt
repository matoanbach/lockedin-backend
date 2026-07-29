package com.lockdin.lockdin_app

internal data class RuleWarningContent(
    val title: String,
    val body: String,
)

internal object RuleWarningCopy {
    fun content(
        appName: String,
        limitMinutes: Int,
        usedMilliseconds: Long,
        eventType: String,
        tone: String,
    ): RuleWarningContent? {
        return when (eventType) {
            "warning_approaching_limit" -> approachingContent(
                appName = appName,
                limitMinutes = limitMinutes,
                usedMilliseconds = usedMilliseconds,
                tone = tone,
            )

            "warning_limit_reached" -> limitReachedContent(
                appName = appName,
                limitMinutes = limitMinutes,
                usedMilliseconds = usedMilliseconds,
                tone = tone,
            )

            else -> null
        }
    }

    private fun approachingContent(
        appName: String,
        limitMinutes: Int,
        usedMilliseconds: Long,
        tone: String,
    ): RuleWarningContent {
        val remainingMilliseconds =
            (limitMinutes.toLong() * 60_000L - usedMilliseconds).coerceAtLeast(0L)
        val remaining = formatRemainingTime(remainingMilliseconds)
        val body = when (tone) {
            "fun" -> "Heads up: only $remaining left before $appName hits today's limit."
            "edgy" -> "$remaining left. $appName is almost out of runway."
            else -> {
                val verb =
                    if (remaining == "1 minute" || remaining == "less than 1 minute") {
                        "remains"
                    } else {
                        "remain"
                    }
                "$remaining $verb before you hit today's $limitMinutes-minute limit for $appName."
            }
        }
        return RuleWarningContent(
            title = "$appName is approaching its limit",
            body = body,
        )
    }

    private fun limitReachedContent(
        appName: String,
        limitMinutes: Int,
        usedMilliseconds: Long,
        tone: String,
    ): RuleWarningContent {
        val title = if (usedMilliseconds > limitMinutes.toLong() * 60_000L) {
            "$appName is over limit"
        } else {
            "$appName reached its limit"
        }
        val body = when (tone) {
            "fun" -> "You just hit today's $limitMinutes-minute limit for $appName. Time to step out for a reset."
            "edgy" -> "Limit reached. Close $appName before it steals more of your day."
            else -> "You have hit today's $limitMinutes-minute limit for $appName."
        }
        return RuleWarningContent(title = title, body = body)
    }

    private fun formatMinuteCount(minutes: Int): String {
        val unit = if (minutes == 1) "minute" else "minutes"
        return "$minutes $unit"
    }

    private fun formatRemainingTime(milliseconds: Long): String {
        if (milliseconds in 1 until 60_000L) {
            return "less than 1 minute"
        }
        return formatMinuteCount(LiveUsageAccounting.completedMinutes(milliseconds))
    }
}
