package com.lockdin.lockdin_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class QueueOwnershipPolicyTest {
    @Test
    fun onlyTheActiveOwnerCanDrain() {
        assertTrue(QueueOwnershipPolicy.isDrainable("account-a", "account-a"))
        assertFalse(QueueOwnershipPolicy.isDrainable("account-b", "account-a"))
        assertFalse(QueueOwnershipPolicy.isDrainable("unclaimed", "account-a"))
        assertFalse(QueueOwnershipPolicy.isDrainable("account-a", null))
    }

    @Test
    fun countsSeparateActiveUnclaimedAndQuarantinedRows() {
        assertEquals(
            QueueOwnershipCounts(activeCount = 2, unclaimedCount = 1, quarantinedCount = 2),
            QueueOwnershipPolicy.counts(
                listOf("account-a", "account-b", "unclaimed", "account-a", "account-c"),
                "account-a",
            ),
        )
    }

    @Test
    fun importRelabelsOnlyUnclaimedOwnership() {
        assertEquals(
            "account-a",
            QueueOwnershipPolicy.ownerAfterImport("unclaimed", "account-a"),
        )
        assertEquals(
            "account-b",
            QueueOwnershipPolicy.ownerAfterImport("account-b", "account-a"),
        )
    }
}
