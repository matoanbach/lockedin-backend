package com.lockdin.lockdin_app

import android.app.AppOpsManager
import android.content.Context
import android.os.Build
import android.os.Process

object UsageAccessChecker {
    fun isGranted(context: Context): Boolean {
        val appOpsManager = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            @Suppress("DEPRECATION")
            appOpsManager.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOpsManager.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        }

        return isGrantedMode(mode)
    }

    internal fun isGrantedMode(mode: Int): Boolean = mode == AppOpsManager.MODE_ALLOWED
}
