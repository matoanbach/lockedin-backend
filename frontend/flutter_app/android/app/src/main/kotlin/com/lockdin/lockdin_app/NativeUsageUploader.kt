package com.lockdin.lockdin_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.util.concurrent.Executors

object NativeUsageUploader {
    private const val PREFS_NAME = "lockdin_native_usage_upload"
    private const val KEY_BASE_URL = "base_url"
    private const val DEFAULT_ANDROID_BASE_URL = "http://10.0.2.2:8000"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val completionCallbacks = mutableListOf<(Map<String, Any>) -> Unit>()

    @Volatile
    private var isDrainingQueue = false

    fun cacheBaseUrl(context: Context, baseUrl: String) {
        val normalized = baseUrl.trim().trimEnd('/')
        if (normalized.isBlank()) {
            return
        }

        prefs(context).edit().putString(KEY_BASE_URL, normalized).apply()
    }

    fun enqueueUsageSlice(
        context: Context,
        slice: UsageSlicePayload,
    ) {
        UsageUploadQueueStore.enqueue(context, slice)
        flushPendingUploads(context)
    }

    fun flushPendingUploads(
        context: Context,
        onComplete: ((Map<String, Any>) -> Unit)? = null,
    ) {
        synchronized(this) {
            if (onComplete != null) {
                completionCallbacks += onComplete
            }
            if (isDrainingQueue) {
                return
            }
            isDrainingQueue = true
        }

        val appContext = context.applicationContext
        executor.execute {
            val summary = drainQueue(appContext)
            val callbacks = synchronized(this) {
                isDrainingQueue = false
                completionCallbacks.toList().also { completionCallbacks.clear() }
            }
            if (callbacks.isNotEmpty()) {
                mainHandler.post {
                    callbacks.forEach { it(summary) }
                }
            }
        }
    }

    private fun drainQueue(context: Context): Map<String, Any> {
        var uploadedCount = 0
        var failedCount = 0
        var lastError = ""
        val baseUrl = prefs(context).getString(KEY_BASE_URL, DEFAULT_ANDROID_BASE_URL)
            ?: DEFAULT_ANDROID_BASE_URL

        while (uploadedCount < MAX_UPLOADS_PER_DRAIN) {
            val batch = UsageUploadQueueStore.nextBatch(context, 1)
            if (batch.isEmpty()) {
                break
            }

            val item = batch.first()
            val responseCode = uploadSingleSlice(baseUrl, item)
            if (responseCode in 200..299) {
                UsageUploadQueueStore.delete(context, item.id)
                RuleEnforcementStore.recordUploadedInterval(
                    context,
                    item.appId,
                    item.startedAtMillis,
                    item.endedAtMillis,
                )
                uploadedCount += 1
                continue
            }

            UsageUploadQueueStore.markFailure(context, item.id)
            failedCount += 1
            lastError = if (responseCode >= 0) {
                "HTTP $responseCode"
            } else {
                "network_error"
            }
            break
        }

        return mapOf(
            "uploadedCount" to uploadedCount,
            "failedCount" to failedCount,
            "pendingCount" to UsageUploadQueueStore.pendingCount(context),
            "lastError" to lastError,
        )
    }

    private fun uploadSingleSlice(baseUrl: String, slice: QueuedUsageSlice): Int {
        val connection = (URL("$baseUrl/api/v1/usage/events").openConnection() as HttpURLConnection)
        return try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")

            val body = JSONObject().apply {
                put(
                    "events",
                    JSONArray().put(
                        JSONObject().apply {
                            put("sourceEventId", slice.sourceEventId)
                            put("appId", slice.appId)
                            put("appName", slice.appName)
                            if (slice.category != null) {
                                put("category", slice.category)
                            }
                            put("startedAt", slice.startedAtIso)
                            put("endedAt", slice.endedAtIso)
                            put("timezone", slice.timezone)
                        },
                    ),
                )
            }

            OutputStreamWriter(connection.outputStream, StandardCharsets.UTF_8).use {
                it.write(body.toString())
            }

            connection.responseCode
        } catch (_: Exception) {
            -1
        } finally {
            connection.disconnect()
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private const val MAX_UPLOADS_PER_DRAIN = 15
}

data class UsageSlicePayload(
    val sourceEventId: String,
    val appId: String,
    val appName: String,
    val category: String?,
    val startedAtMillis: Long,
    val endedAtMillis: Long,
    val startedAtIso: String,
    val endedAtIso: String,
    val timezone: String,
)
