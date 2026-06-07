package com.lockdin.lockdin_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object NativeWarningNotifier {
    private const val TAG = "LockdInWarnings"

    fun areNotificationsEnabled(context: Context): Boolean {
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    fun diagnostics(context: Context): Map<String, Any> {
        ensureChannel(context)
        val appEnabled = areNotificationsEnabled(context)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return mapOf(
                "appEnabled" to appEnabled,
                "channelId" to CHANNEL_ID,
                "channelExists" to true,
                "channelEnabled" to appEnabled,
                "channelImportance" to NotificationManager.IMPORTANCE_HIGH,
                "channelImportanceLabel" to "high",
            )
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = manager.getNotificationChannel(CHANNEL_ID)
        val importance = channel?.importance ?: NotificationManager.IMPORTANCE_NONE
        return mapOf(
            "appEnabled" to appEnabled,
            "channelId" to CHANNEL_ID,
            "channelExists" to (channel != null),
            "channelEnabled" to (importance != NotificationManager.IMPORTANCE_NONE),
            "channelImportance" to importance,
            "channelImportanceLabel" to importanceLabel(importance),
        )
    }

    fun showWarning(
        context: Context,
        notificationId: Int,
        title: String,
        body: String,
    ): Boolean {
        Log.d(TAG, "Attempting warning notification id=$notificationId title=$title")
        if (!areNotificationsEnabled(context)) {
            Log.w(TAG, "Skipping warning notification because app notifications are disabled")
            return false
        }

        ensureChannel(context)
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            Intent(context, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
                )
                putExtra(EXTRA_LAUNCH_ROUTE, "/rules")
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_lockdin)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        NotificationManagerCompat.from(context).notify(notificationId, notification)
        Log.d(TAG, "Posted warning notification id=$notificationId")
        return true
    }

    fun showTestWarning(context: Context): Boolean {
        Log.d(TAG, "Triggering native test warning")
        return showWarning(
            context = context,
            notificationId = TEST_NOTIFICATION_ID,
            title = "LockdIn test warning",
            body = "If you can see this, Android local warnings are working on this device.",
        )
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "LockdIn warnings",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Limit warnings and reminders from LockdIn."
        }
        manager.createNotificationChannel(channel)
    }

    private fun importanceLabel(importance: Int): String {
        return when (importance) {
            NotificationManager.IMPORTANCE_NONE -> "none"
            NotificationManager.IMPORTANCE_MIN -> "min"
            NotificationManager.IMPORTANCE_LOW -> "low"
            NotificationManager.IMPORTANCE_DEFAULT -> "default"
            NotificationManager.IMPORTANCE_HIGH -> "high"
            NotificationManager.IMPORTANCE_MAX -> "max"
            else -> "unknown($importance)"
        }
    }

    const val EXTRA_LAUNCH_ROUTE = "lockdin_launch_route"
    private const val CHANNEL_ID = "lockdin_warnings"
    private const val TEST_NOTIFICATION_ID = 40_401
}
