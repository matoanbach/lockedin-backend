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

    data class AuthContext(
        val ownerGeneration: String,
        val accessToken: String,
        val version: Long,
    )

    @Volatile
    private var authContext: AuthContext? = null

    @Volatile
    private var authContextVersion = 0L

    @Volatile
    private var isDrainingQueue = false

    fun configureAuthContext(ownerGeneration: String, accessToken: String) {
        require(ownerGeneration.isNotBlank())
        require(accessToken.isNotBlank())
        synchronized(this) {
            authContextVersion += 1
            authContext = AuthContext(ownerGeneration, accessToken, authContextVersion)
        }
    }

    fun clearAuthContext() {
        synchronized(this) {
            authContextVersion += 1
            authContext = null
        }
    }

    fun currentOwnerGeneration(): String? = authContext?.ownerGeneration

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
        val owner = authContext?.ownerGeneration ?: QueueOwnershipPolicy.UNCLAIMED_OWNER
        UsageUploadQueueStore.enqueue(context, owner, slice)
        if (authContext != null) {
            flushPendingUploads(context)
        }
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
        val contextSnapshot = authContext
            ?: return emptySummary(context, null)
        val baseUrl = prefs(context).getString(KEY_BASE_URL, DEFAULT_ANDROID_BASE_URL)
            ?: DEFAULT_ANDROID_BASE_URL

        while (uploadedCount < MAX_UPLOADS_PER_DRAIN) {
            if (authContext != contextSnapshot) {
                lastError = "auth_context_changed"
                break
            }
            val batch = UsageUploadQueueStore.nextBatch(
                context,
                contextSnapshot.ownerGeneration,
                1,
            )
            if (batch.isEmpty()) {
                break
            }

            val item = batch.first()
            val responseCode = uploadSingleSlice(baseUrl, contextSnapshot.accessToken, item)
            if (authContext != contextSnapshot) {
                lastError = "auth_context_changed"
                break
            }
            if (responseCode in 200..299) {
                UsageUploadQueueStore.delete(context, item.id, contextSnapshot.ownerGeneration)
                RuleEnforcementStore.recordUploadedInterval(
                    context,
                    item.appId,
                    item.startedAtMillis,
                    item.endedAtMillis,
                )
                uploadedCount += 1
                continue
            }

            UsageUploadQueueStore.markFailure(context, item.id, contextSnapshot.ownerGeneration)
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
            "pendingCount" to UsageUploadQueueStore.pendingCount(
                context,
                contextSnapshot.ownerGeneration,
            ),
            "lastError" to lastError,
        )
    }

    private fun emptySummary(context: Context, ownerGeneration: String?): Map<String, Any> = mapOf(
        "uploadedCount" to 0,
        "failedCount" to 0,
        "pendingCount" to if (ownerGeneration == null) {
            0
        } else {
            UsageUploadQueueStore.pendingCount(context, ownerGeneration)
        },
        "lastError" to if (ownerGeneration == null) "authentication_required" else "",
    )

    private fun uploadSingleSlice(
        baseUrl: String,
        accessToken: String,
        slice: QueuedUsageSlice,
    ): Int {
        val connection = (URL("$baseUrl/api/v1/usage/events").openConnection() as HttpURLConnection)
        return try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $accessToken")

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
