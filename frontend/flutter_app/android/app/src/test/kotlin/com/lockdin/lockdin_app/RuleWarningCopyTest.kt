package com.lockdin.lockdin_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class RuleWarningCopyTest {
    @Test
    fun approachingWarningUsesSingularCopyForEveryTone() {
        assertEquals(
            "Heads up: only 1 minute left before Messages hits today's limit.",
            approachingBody("fun", usedMinutes = 4),
        )
        assertEquals(
            "1 minute left. Messages is almost out of runway.",
            approachingBody("edgy", usedMinutes = 4),
        )
        assertEquals(
            "1 minute remains before you hit today's 5-minute limit for Messages.",
            approachingBody("professional", usedMinutes = 4),
        )
    }

    @Test
    fun approachingWarningRetainsPluralAgreement() {
        assertEquals(
            "Heads up: only 2 minutes left before Messages hits today's limit.",
            approachingBody("fun", usedMinutes = 3),
        )
        assertEquals(
            "2 minutes left. Messages is almost out of runway.",
            approachingBody("edgy", usedMinutes = 3),
        )
        assertEquals(
            "2 minutes remain before you hit today's 5-minute limit for Messages.",
            approachingBody("professional", usedMinutes = 3),
        )
    }

    @Test
    fun limitReachedCopyCoversEveryToneAtAndOverTheLimit() {
        for (tone in listOf("fun", "edgy", "professional")) {
            val atLimit = content(
                eventType = "warning_limit_reached",
                tone = tone,
                usedMinutes = 5,
            )
            val overLimit = content(
                eventType = "warning_limit_reached",
                tone = tone,
                usedMinutes = 6,
            )

            assertEquals("Messages reached its limit", atLimit.title)
            assertEquals("Messages is over limit", overLimit.title)
            assertFalse(atLimit.body.contains("1 minutes"))
            assertFalse(overLimit.body.contains("1 minutes"))
        }
    }

    private fun approachingBody(tone: String, usedMinutes: Int): String {
        return content(
            eventType = "warning_approaching_limit",
            tone = tone,
            usedMinutes = usedMinutes,
        ).body
    }

    private fun content(
        eventType: String,
        tone: String,
        usedMinutes: Int,
    ): RuleWarningContent {
        return requireNotNull(
            RuleWarningCopy.content(
                appName = "Messages",
                limitMinutes = 5,
                usedMinutes = usedMinutes,
                eventType = eventType,
                tone = tone,
            ),
        )
    }
}
