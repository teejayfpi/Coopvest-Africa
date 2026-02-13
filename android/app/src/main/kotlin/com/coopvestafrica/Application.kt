package com.coopvestafrica

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.view.FlutterMain

class Application : Application() {

    companion object {
        const val NOTIFICATION_CHANNEL_ID = "coopvest_notifications"
        const val NOTIFICATION_CHANNEL_NAME = "Coopvest Notifications"
    }

    override fun onCreate() {
        super.onCreate()
        FlutterMain.startInitialization(this)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for Coopvest Africa app"
                enableLights(true)
                enableVibration(true)
                setShowBadge(true)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}
