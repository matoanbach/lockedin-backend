package com.lockdin.lockdin_app

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

data class QueuedUsageSlice(
    val id: Long,
    val ownerGeneration: String,
    val sourceEventId: String,
    val appId: String,
    val appName: String,
    val category: String?,
    val startedAtMillis: Long,
    val endedAtMillis: Long,
    val startedAtIso: String,
    val endedAtIso: String,
    val timezone: String,
    val retryCount: Int,
)

data class QueueOwnershipCounts(
    val activeCount: Int,
    val unclaimedCount: Int,
    val quarantinedCount: Int,
) {
    fun toMap(): Map<String, Int> = mapOf(
        "activeCount" to activeCount,
        "unclaimedCount" to unclaimedCount,
        "quarantinedCount" to quarantinedCount,
    )
}

object QueueOwnershipPolicy {
    const val UNCLAIMED_OWNER = "unclaimed"

    fun isDrainable(rowOwner: String, activeOwner: String?): Boolean =
        activeOwner != null && rowOwner == activeOwner

    fun counts(owners: List<String>, activeOwner: String): QueueOwnershipCounts =
        QueueOwnershipCounts(
            activeCount = owners.count { it == activeOwner },
            unclaimedCount = owners.count { it == UNCLAIMED_OWNER },
            quarantinedCount = owners.count {
                it != activeOwner && it != UNCLAIMED_OWNER
            },
        )

    fun ownerAfterImport(rowOwner: String, activeOwner: String): String =
        if (rowOwner == UNCLAIMED_OWNER) activeOwner else rowOwner
}

object UsageUploadQueueStore {
    fun enqueue(context: Context, ownerGeneration: String, slice: UsageSlicePayload) {
        helper(context).writableDatabase.insertWithOnConflict(
            TABLE_NAME,
            null,
            ContentValues().apply {
                put(COLUMN_OWNER_GENERATION, ownerGeneration)
                put(COLUMN_SOURCE_EVENT_ID, slice.sourceEventId)
                put(COLUMN_APP_ID, slice.appId)
                put(COLUMN_APP_NAME, slice.appName)
                put(COLUMN_CATEGORY, slice.category)
                put(COLUMN_STARTED_AT_MILLIS, slice.startedAtMillis)
                put(COLUMN_ENDED_AT_MILLIS, slice.endedAtMillis)
                put(COLUMN_STARTED_AT_ISO, slice.startedAtIso)
                put(COLUMN_ENDED_AT_ISO, slice.endedAtIso)
                put(COLUMN_TIMEZONE, slice.timezone)
                put(COLUMN_RETRY_COUNT, 0)
                put(COLUMN_CREATED_AT_MILLIS, System.currentTimeMillis())
            },
            SQLiteDatabase.CONFLICT_IGNORE,
        )
    }

    fun nextBatch(context: Context, ownerGeneration: String, limit: Int): List<QueuedUsageSlice> {
        val slices = mutableListOf<QueuedUsageSlice>()
        helper(context).readableDatabase.query(
            TABLE_NAME,
            null,
            "$COLUMN_OWNER_GENERATION = ?",
            arrayOf(ownerGeneration),
            null,
            null,
            "$COLUMN_CREATED_AT_MILLIS ASC, $COLUMN_ID ASC",
            limit.toString(),
        ).use { cursor ->
            while (cursor.moveToNext()) {
                slices += QueuedUsageSlice(
                    id = cursor.getLong(cursor.getColumnIndexOrThrow(COLUMN_ID)),
                    ownerGeneration = cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_OWNER_GENERATION)),
                    sourceEventId = cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_SOURCE_EVENT_ID)),
                    appId = cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_APP_ID)),
                    appName = cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_APP_NAME)),
                    category = cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_CATEGORY)),
                    startedAtMillis = cursor.getLong(cursor.getColumnIndexOrThrow(COLUMN_STARTED_AT_MILLIS)),
                    endedAtMillis = cursor.getLong(cursor.getColumnIndexOrThrow(COLUMN_ENDED_AT_MILLIS)),
                    startedAtIso = cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_STARTED_AT_ISO)),
                    endedAtIso = cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_ENDED_AT_ISO)),
                    timezone = cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_TIMEZONE)),
                    retryCount = cursor.getInt(cursor.getColumnIndexOrThrow(COLUMN_RETRY_COUNT)),
                )
            }
        }
        return slices
    }

    fun delete(context: Context, id: Long, ownerGeneration: String) {
        helper(context).writableDatabase.delete(
            TABLE_NAME,
            "$COLUMN_ID = ? AND $COLUMN_OWNER_GENERATION = ?",
            arrayOf(id.toString(), ownerGeneration),
        )
    }

    fun markFailure(context: Context, id: Long, ownerGeneration: String) {
        helper(context).writableDatabase.execSQL(
            "UPDATE $TABLE_NAME SET $COLUMN_RETRY_COUNT = $COLUMN_RETRY_COUNT + 1, " +
                "$COLUMN_LAST_ATTEMPT_AT_MILLIS = ? WHERE $COLUMN_ID = ? AND $COLUMN_OWNER_GENERATION = ?",
            arrayOf<Any>(System.currentTimeMillis(), id, ownerGeneration),
        )
    }

    fun ownershipCounts(context: Context, activeOwner: String): QueueOwnershipCounts {
        var active = 0
        var unclaimed = 0
        var quarantined = 0
        helper(context).readableDatabase.rawQuery(
            "SELECT $COLUMN_OWNER_GENERATION, COUNT(*) FROM $TABLE_NAME GROUP BY $COLUMN_OWNER_GENERATION",
            null,
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val owner = cursor.getString(0)
                val count = cursor.getInt(1)
                when (owner) {
                    activeOwner -> active += count
                    QueueOwnershipPolicy.UNCLAIMED_OWNER -> unclaimed += count
                    else -> quarantined += count
                }
            }
        }
        return QueueOwnershipCounts(active, unclaimed, quarantined)
    }

    fun pendingCount(context: Context, ownerGeneration: String): Int =
        countWhere(context, "$COLUMN_OWNER_GENERATION = ?", arrayOf(ownerGeneration))

    fun resolveUnclaimed(context: Context, activeOwner: String, import: Boolean) {
        val db = helper(context).writableDatabase
        db.beginTransaction()
        try {
            if (import) {
                db.execSQL(
                    "UPDATE OR IGNORE $TABLE_NAME SET $COLUMN_OWNER_GENERATION = ? " +
                        "WHERE $COLUMN_OWNER_GENERATION = ?",
                    arrayOf(activeOwner, QueueOwnershipPolicy.UNCLAIMED_OWNER),
                )
                // A stable source ID already owned by this account wins over its unclaimed duplicate.
                db.delete(
                    TABLE_NAME,
                    "$COLUMN_OWNER_GENERATION = ?",
                    arrayOf(QueueOwnershipPolicy.UNCLAIMED_OWNER),
                )
            } else {
                db.delete(
                    TABLE_NAME,
                    "$COLUMN_OWNER_GENERATION = ?",
                    arrayOf(QueueOwnershipPolicy.UNCLAIMED_OWNER),
                )
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    private fun countWhere(context: Context, selection: String, args: Array<String>): Int {
        helper(context).readableDatabase.rawQuery(
            "SELECT COUNT(*) FROM $TABLE_NAME WHERE $selection",
            args,
        ).use { cursor ->
            if (cursor.moveToFirst()) return cursor.getInt(0)
        }
        return 0
    }

    private fun helper(context: Context): QueueDbHelper =
        QueueDbHelper.getInstance(context.applicationContext)

    private const val TABLE_NAME = "usage_upload_queue"
    private const val LEGACY_TABLE_NAME = "usage_upload_queue_v1"
    private const val COLUMN_ID = "id"
    private const val COLUMN_OWNER_GENERATION = "owner_generation"
    private const val COLUMN_SOURCE_EVENT_ID = "source_event_id"
    private const val COLUMN_APP_ID = "app_id"
    private const val COLUMN_APP_NAME = "app_name"
    private const val COLUMN_CATEGORY = "category"
    private const val COLUMN_STARTED_AT_MILLIS = "started_at_millis"
    private const val COLUMN_ENDED_AT_MILLIS = "ended_at_millis"
    private const val COLUMN_STARTED_AT_ISO = "started_at_iso"
    private const val COLUMN_ENDED_AT_ISO = "ended_at_iso"
    private const val COLUMN_TIMEZONE = "timezone"
    private const val COLUMN_RETRY_COUNT = "retry_count"
    private const val COLUMN_CREATED_AT_MILLIS = "created_at_millis"
    private const val COLUMN_LAST_ATTEMPT_AT_MILLIS = "last_attempt_at_millis"

    private class QueueDbHelper private constructor(context: Context) :
        SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {
        override fun onCreate(db: SQLiteDatabase) = createVersionTwoSchema(db)

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            if (oldVersion == 1 && newVersion >= 2) {
                db.execSQL("ALTER TABLE $TABLE_NAME RENAME TO $LEGACY_TABLE_NAME")
                createVersionTwoSchema(db)
                db.execSQL(
                    """
                    INSERT INTO $TABLE_NAME (
                        $COLUMN_ID, $COLUMN_OWNER_GENERATION, $COLUMN_SOURCE_EVENT_ID,
                        $COLUMN_APP_ID, $COLUMN_APP_NAME, $COLUMN_CATEGORY,
                        $COLUMN_STARTED_AT_MILLIS, $COLUMN_ENDED_AT_MILLIS,
                        $COLUMN_STARTED_AT_ISO, $COLUMN_ENDED_AT_ISO, $COLUMN_TIMEZONE,
                        $COLUMN_RETRY_COUNT, $COLUMN_CREATED_AT_MILLIS,
                        $COLUMN_LAST_ATTEMPT_AT_MILLIS
                    )
                    SELECT id, '${QueueOwnershipPolicy.UNCLAIMED_OWNER}', source_event_id,
                        app_id, app_name, category, started_at_millis, ended_at_millis,
                        started_at_iso, ended_at_iso, timezone, retry_count,
                        created_at_millis, last_attempt_at_millis
                    FROM $LEGACY_TABLE_NAME
                    """.trimIndent(),
                )
                db.execSQL("DROP TABLE $LEGACY_TABLE_NAME")
                return
            }
            throw IllegalStateException("Unsupported usage queue migration $oldVersion to $newVersion")
        }

        private fun createVersionTwoSchema(db: SQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE $TABLE_NAME (
                    $COLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                    $COLUMN_OWNER_GENERATION TEXT NOT NULL,
                    $COLUMN_SOURCE_EVENT_ID TEXT NOT NULL,
                    $COLUMN_APP_ID TEXT NOT NULL,
                    $COLUMN_APP_NAME TEXT NOT NULL,
                    $COLUMN_CATEGORY TEXT,
                    $COLUMN_STARTED_AT_MILLIS INTEGER NOT NULL,
                    $COLUMN_ENDED_AT_MILLIS INTEGER NOT NULL,
                    $COLUMN_STARTED_AT_ISO TEXT NOT NULL,
                    $COLUMN_ENDED_AT_ISO TEXT NOT NULL,
                    $COLUMN_TIMEZONE TEXT NOT NULL,
                    $COLUMN_RETRY_COUNT INTEGER NOT NULL DEFAULT 0,
                    $COLUMN_CREATED_AT_MILLIS INTEGER NOT NULL,
                    $COLUMN_LAST_ATTEMPT_AT_MILLIS INTEGER,
                    UNIQUE ($COLUMN_OWNER_GENERATION, $COLUMN_SOURCE_EVENT_ID)
                )
                """.trimIndent(),
            )
            db.execSQL(
                "CREATE INDEX ix_usage_upload_queue_owner_created ON " +
                    "$TABLE_NAME($COLUMN_OWNER_GENERATION, $COLUMN_CREATED_AT_MILLIS, $COLUMN_ID)",
            )
        }

        companion object {
            @Volatile
            private var instance: QueueDbHelper? = null

            fun getInstance(context: Context): QueueDbHelper =
                instance ?: synchronized(this) {
                    instance ?: QueueDbHelper(context).also { instance = it }
                }

            private const val DATABASE_NAME = "lockdin_usage_queue.db"
            private const val DATABASE_VERSION = 2
        }
    }
}
