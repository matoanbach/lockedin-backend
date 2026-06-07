package com.lockdin.lockdin_app

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

data class QueuedUsageSlice(
    val id: Long,
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

object UsageUploadQueueStore {
    fun enqueue(context: Context, slice: UsageSlicePayload) {
        helper(context).writableDatabase.insertWithOnConflict(
            TABLE_NAME,
            null,
            ContentValues().apply {
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

    fun nextBatch(context: Context, limit: Int): List<QueuedUsageSlice> {
        val slices = mutableListOf<QueuedUsageSlice>()
        helper(context).readableDatabase.query(
            TABLE_NAME,
            null,
            null,
            null,
            null,
            null,
            "$COLUMN_CREATED_AT_MILLIS ASC, $COLUMN_ID ASC",
            limit.toString(),
        ).use { cursor ->
            while (cursor.moveToNext()) {
                slices += QueuedUsageSlice(
                    id = cursor.getLong(cursor.getColumnIndexOrThrow(COLUMN_ID)),
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

    fun delete(context: Context, id: Long) {
        helper(context).writableDatabase.delete(
            TABLE_NAME,
            "$COLUMN_ID = ?",
            arrayOf(id.toString()),
        )
    }

    fun markFailure(context: Context, id: Long) {
        helper(context).writableDatabase.execSQL(
            "UPDATE $TABLE_NAME SET $COLUMN_RETRY_COUNT = $COLUMN_RETRY_COUNT + 1, $COLUMN_LAST_ATTEMPT_AT_MILLIS = ? WHERE $COLUMN_ID = ?",
            arrayOf(System.currentTimeMillis(), id),
        )
    }

    fun pendingCount(context: Context): Int {
        helper(context).readableDatabase.rawQuery(
            "SELECT COUNT(*) FROM $TABLE_NAME",
            null,
        ).use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getInt(0)
            }
        }

        return 0
    }

    private fun helper(context: Context): QueueDbHelper {
        return QueueDbHelper.getInstance(context.applicationContext)
    }

    private const val TABLE_NAME = "usage_upload_queue"
    private const val COLUMN_ID = "id"
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
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE $TABLE_NAME (
                    $COLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                    $COLUMN_SOURCE_EVENT_ID TEXT NOT NULL UNIQUE,
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
                    $COLUMN_LAST_ATTEMPT_AT_MILLIS INTEGER
                )
                """.trimIndent(),
            )
            db.execSQL(
                "CREATE INDEX ix_usage_upload_queue_created_at ON $TABLE_NAME($COLUMN_CREATED_AT_MILLIS, $COLUMN_ID)",
            )
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            db.execSQL("DROP TABLE IF EXISTS $TABLE_NAME")
            onCreate(db)
        }

        companion object {
            @Volatile
            private var instance: QueueDbHelper? = null

            fun getInstance(context: Context): QueueDbHelper {
                return instance ?: synchronized(this) {
                    instance ?: QueueDbHelper(context).also { instance = it }
                }
            }

            private const val DATABASE_NAME = "lockdin_usage_queue.db"
            private const val DATABASE_VERSION = 1
        }
    }
}
