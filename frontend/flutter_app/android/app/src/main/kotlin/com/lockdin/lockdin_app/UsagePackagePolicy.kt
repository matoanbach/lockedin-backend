package com.lockdin.lockdin_app

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.os.Build

data class LaunchableAppInfo(
    val appId: String,
    val appName: String,
) {
    fun toChannelMap(): Map<String, String> = mapOf(
        "appId" to appId,
        "appName" to appName,
    )
}

object UsagePackagePolicy {
    private val knownLauncherPackages = setOf(
        "com.android.launcher",
        "com.android.launcher2",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.huawei.android.launcher",
        "com.miui.home",
        "com.oneplus.launcher",
        "com.oppo.launcher",
        "com.sec.android.app.launcher",
        "com.vivo.launcher",
    )

    fun isKnownLauncherPackage(packageName: String): Boolean =
        packageName.trim().lowercase() in knownLauncherPackages

    fun excludedPackages(context: Context): Set<String> = buildSet {
        add(context.packageName)
        addAll(knownLauncherPackages)
        addAll(
            queryActivities(
                context,
                Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
            ).mapNotNull { it.activityInfo?.packageName },
        )
    }

    fun launchableApps(context: Context): List<LaunchableAppInfo> {
        val excluded = excludedPackages(context)
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return queryActivities(context, launcherIntent)
            .mapNotNull { resolveInfo ->
                val appId = resolveInfo.activityInfo?.packageName ?: return@mapNotNull null
                if (appId in excluded) {
                    return@mapNotNull null
                }
                val appName = resolveInfo.loadLabel(context.packageManager)
                    .toString()
                    .trim()
                    .ifBlank { appId }
                LaunchableAppInfo(appId = appId, appName = appName)
            }
            .distinctBy(LaunchableAppInfo::appId)
            .sortedWith(
                compareBy<LaunchableAppInfo> { it.appName.lowercase() }
                    .thenBy(LaunchableAppInfo::appId),
            )
    }

    private fun queryActivities(context: Context, intent: Intent): List<ResolveInfo> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.queryIntentActivities(intent, 0)
        }
}
