package com.lockdin.lockdin_app

import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneId

data class CachedRuleStatus(
    val ruleId: String,
    val appId: String,
    val appName: String,
    val usageDate: String,
    val enabled: Boolean,
    val limitMinutes: Int,
    val usedMinutes: Int,
    val status: String,
)

data class PendingIntervention(
    val ruleId: String,
    val appId: String,
    val appName: String,
    val usageDate: String,
    val usedMinutes: Int,
    val limitMinutes: Int,
    val status: String,
    val source: String,
)

data class UploadedUsageInterval(
    val startMillis: Long,
    val endMillis: Long,
)

object RuleEnforcementStore {
    private const val PREFS_NAME = "lockdin_enforcement"
    private const val KEY_RULE_STATUSES = "rule_statuses_json"
    private const val KEY_PENDING_INTERVENTION = "pending_intervention_json"
    private const val KEY_LAST_INTERVENED_PACKAGE = "last_intervened_package"
    private const val KEY_LAST_INTERVENED_AT = "last_intervened_at"
    private const val KEY_LOCAL_USAGE_MILLIS = "local_usage_millis_json"
    private const val KEY_LIVE_UPLOADED_INTERVALS = "live_uploaded_intervals_json"

    fun cacheRuleStatuses(context: Context, rawStatuses: List<Map<String, Any?>>) {
        val statuses = rawStatuses.mapNotNull(::cachedRuleStatusFromMap)
        val json = JSONArray()

        for (status in statuses) {
            json.put(
                JSONObject().apply {
                    put("ruleId", status.ruleId)
                    put("appId", status.appId)
                    put("appName", status.appName)
                    put("usageDate", status.usageDate)
                    put("enabled", status.enabled)
                    put("limitMinutes", status.limitMinutes)
                    put("usedMinutes", status.usedMinutes)
                    put("status", status.status)
                },
            )
        }

        prefs(context)
            .edit()
            .putString(KEY_RULE_STATUSES, json.toString())
            .putString(KEY_LOCAL_USAGE_MILLIS, JSONObject().toString())
            .apply()
    }

    fun findRuleForPackage(context: Context, packageName: String): CachedRuleStatus? {
        val canonicalPackageName = canonicalizeAppId(packageName)
        return loadRuleStatuses(context).firstOrNull {
            it.enabled && canonicalizeAppId(it.appId) == canonicalPackageName
        }
    }

    fun calculateLiveUsedMinutes(
        context: Context,
        rule: CachedRuleStatus,
        currentSessionMillis: Long,
    ): Int {
        val usageDate = currentUsageDate()
        val baseMinutes = if (rule.usageDate == usageDate) rule.usedMinutes else 0
        val localMillis = loadLocalUsageMillis(context).optLong(
            localUsageKey(rule.appId, usageDate),
            0L,
        )
        return baseMinutes + ((localMillis + currentSessionMillis) / MINUTE_MILLIS).toInt()
    }

    fun addLocalUsageMillis(context: Context, appId: String, usageDate: String, durationMillis: Long) {
        if (durationMillis <= 0L) {
            return
        }

        val usageByKey = loadLocalUsageMillis(context)
        val key = localUsageKey(appId, usageDate)
        val existing = usageByKey.optLong(key, 0L)
        usageByKey.put(key, existing + durationMillis)
        prefs(context).edit().putString(KEY_LOCAL_USAGE_MILLIS, usageByKey.toString()).apply()
    }

    fun recordUploadedInterval(
        context: Context,
        appId: String,
        startMillis: Long,
        endMillis: Long,
    ) {
        if (endMillis <= startMillis) {
            return
        }

        val root = loadUploadedIntervalsRoot(context)
        val key = canonicalizeAppId(appId)
        val mergedIntervals = mutableListOf<UploadedUsageInterval>()
        val existing = root.optJSONArray(key) ?: JSONArray()

        for (index in 0 until existing.length()) {
            val interval = existing.optJSONObject(index) ?: continue
            mergedIntervals += UploadedUsageInterval(
                startMillis = interval.optLong("startMillis"),
                endMillis = interval.optLong("endMillis"),
            )
        }

        mergedIntervals += UploadedUsageInterval(startMillis = startMillis, endMillis = endMillis)
        val sortedIntervals = mergedIntervals
            .filter { it.endMillis > it.startMillis }
            .sortedBy { it.startMillis }

        val compacted = mutableListOf<UploadedUsageInterval>()
        for (interval in sortedIntervals) {
            val last = compacted.lastOrNull()
            if (last == null || interval.startMillis > last.endMillis) {
                compacted += interval
                continue
            }

            compacted[compacted.lastIndex] = UploadedUsageInterval(
                startMillis = last.startMillis,
                endMillis = maxOf(last.endMillis, interval.endMillis),
            )
        }

        val cutoffMillis = System.currentTimeMillis() - LIVE_INTERVAL_RETENTION_MILLIS
        val persisted = JSONArray()
        for (interval in compacted) {
            if (interval.endMillis < cutoffMillis) {
                continue
            }

            persisted.put(
                JSONObject().apply {
                    put("startMillis", interval.startMillis)
                    put("endMillis", interval.endMillis)
                },
            )
        }

        root.put(key, persisted)
        prefs(context).edit().putString(KEY_LIVE_UPLOADED_INTERVALS, root.toString()).apply()
    }

    fun uploadedIntervalsForPackage(
        context: Context,
        appId: String,
        startMillis: Long,
        endMillis: Long,
    ): List<UploadedUsageInterval> {
        val canonicalAppId = canonicalizeAppId(appId)
        val intervals = loadUploadedIntervalsRoot(context).optJSONArray(canonicalAppId) ?: return emptyList()
        val matches = mutableListOf<UploadedUsageInterval>()

        for (index in 0 until intervals.length()) {
            val item = intervals.optJSONObject(index) ?: continue
            val interval = UploadedUsageInterval(
                startMillis = item.optLong("startMillis"),
                endMillis = item.optLong("endMillis"),
            )
            if (interval.endMillis <= startMillis || interval.startMillis >= endMillis) {
                continue
            }

            matches += interval
        }

        return matches
    }

    fun queuePendingIntervention(
        context: Context,
        pending: PendingIntervention,
    ) {
        val json = JSONObject().apply {
            put("ruleId", pending.ruleId)
            put("appId", pending.appId)
            put("appName", pending.appName)
            put("usageDate", pending.usageDate)
            put("usedMinutes", pending.usedMinutes)
            put("limitMinutes", pending.limitMinutes)
            put("status", pending.status)
            put("source", pending.source)
        }

        prefs(context).edit().putString(KEY_PENDING_INTERVENTION, json.toString()).apply()
    }

    fun consumePendingIntervention(context: Context): Map<String, Any?>? {
        val prefs = prefs(context)
        val raw = prefs.getString(KEY_PENDING_INTERVENTION, null) ?: return null
        prefs.edit().remove(KEY_PENDING_INTERVENTION).apply()

        val json = JSONObject(raw)
        return mapOf(
            "ruleId" to json.optString("ruleId"),
            "appId" to json.optString("appId"),
            "appName" to json.optString("appName"),
            "usageDate" to json.optString("usageDate"),
            "usedMinutes" to json.optInt("usedMinutes"),
            "limitMinutes" to json.optInt("limitMinutes"),
            "status" to json.optString("status"),
            "source" to json.optString("source"),
        )
    }

    fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val expectedComponent = ComponentName(context, LockdinAccessibilityService::class.java)
            .flattenToString()
            .lowercase()

        return enabledServices
            .split(':')
            .any { it.lowercase() == expectedComponent }
    }

    fun markIntervened(context: Context, packageName: String, timestampMillis: Long) {
        prefs(context)
            .edit()
            .putString(KEY_LAST_INTERVENED_PACKAGE, packageName)
            .putLong(KEY_LAST_INTERVENED_AT, timestampMillis)
            .apply()
    }

    fun clearInterventionCooldown(context: Context) {
        prefs(context)
            .edit()
            .remove(KEY_LAST_INTERVENED_PACKAGE)
            .remove(KEY_LAST_INTERVENED_AT)
            .apply()
    }

    fun wasRecentlyIntervened(
        context: Context,
        packageName: String,
        cooldownMillis: Long,
        timestampMillis: Long,
    ): Boolean {
        val prefs = prefs(context)
        val lastPackage = prefs.getString(KEY_LAST_INTERVENED_PACKAGE, null) ?: return false
        val lastTimestamp = prefs.getLong(KEY_LAST_INTERVENED_AT, 0L)
        return lastPackage == packageName && timestampMillis - lastTimestamp < cooldownMillis
    }

    fun currentUsageDate(): String = LocalDate.now(ZoneId.systemDefault()).toString()

    fun canonicalizeAppId(appId: String): String {
        return when (appId.trim().lowercase()) {
            "com.youtube.android" -> "com.google.android.youtube"
            else -> appId.trim()
        }
    }

    private fun loadRuleStatuses(context: Context): List<CachedRuleStatus> {
        val raw = prefs(context).getString(KEY_RULE_STATUSES, null) ?: return emptyList()
        val json = JSONArray(raw)
        val statuses = mutableListOf<CachedRuleStatus>()

        for (index in 0 until json.length()) {
            val item = json.optJSONObject(index) ?: continue
            statuses += CachedRuleStatus(
                ruleId = item.optString("ruleId"),
                appId = item.optString("appId"),
                appName = item.optString("appName"),
                usageDate = item.optString("usageDate"),
                enabled = item.optBoolean("enabled"),
                limitMinutes = item.optInt("limitMinutes"),
                usedMinutes = item.optInt("usedMinutes"),
                status = item.optString("status"),
            )
        }

        return statuses
    }

    private fun loadLocalUsageMillis(context: Context): JSONObject {
        val raw = prefs(context).getString(KEY_LOCAL_USAGE_MILLIS, null)
        return if (raw.isNullOrBlank()) {
            JSONObject()
        } else {
            JSONObject(raw)
        }
    }

    private fun loadUploadedIntervalsRoot(context: Context): JSONObject {
        val raw = prefs(context).getString(KEY_LIVE_UPLOADED_INTERVALS, null)
        return if (raw.isNullOrBlank()) {
            JSONObject()
        } else {
            JSONObject(raw)
        }
    }

    private fun cachedRuleStatusFromMap(raw: Map<String, Any?>): CachedRuleStatus? {
        val ruleId = raw["ruleId"] as? String ?: return null
        val appId = raw["appId"] as? String ?: return null
        val appName = raw["appName"] as? String ?: appId
        val usageDate = raw["usageDate"] as? String ?: currentUsageDate()
        val enabled = raw["enabled"] as? Boolean ?: false
        val limitMinutes = (raw["limitMinutes"] as? Number)?.toInt() ?: return null
        val usedMinutes = (raw["usedMinutes"] as? Number)?.toInt() ?: 0
        val status = raw["status"] as? String ?: "under_limit"

        return CachedRuleStatus(
            ruleId = ruleId,
            appId = appId,
            appName = appName,
            usageDate = usageDate,
            enabled = enabled,
            limitMinutes = limitMinutes,
            usedMinutes = usedMinutes,
            status = status,
        )
    }

    private fun localUsageKey(appId: String, usageDate: String): String =
        "$usageDate|${canonicalizeAppId(appId)}"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private const val LIVE_INTERVAL_RETENTION_MILLIS = 14L * 24L * 60L * 60L * 1000L
    private const val MINUTE_MILLIS = 60_000L
}
