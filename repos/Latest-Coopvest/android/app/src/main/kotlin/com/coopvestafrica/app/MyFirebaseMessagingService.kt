package com.coopvestafrica.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import android.content.Context

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        // Handle notification message
        remoteMessage.notification?.let {
            sendNotification(it.title, it.body)
        }

        // Handle data message
        if (remoteMessage.data.isNotEmpty()) {
            // Handle data payload
        }
    }

    override fun onNewToken(token: String) {
        // Send token to server
        sendRegistrationToServer(token)
    }

    private fun sendNotification(title: String?, body: String?) {
        val channelId = "coopvest_notifications"
        val notificationBuilder = NotificationCompat.Builder(this as Context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Coopvest Notifications", NotificationManager.IMPORTANCE_HIGH)
            notificationManager.createNotificationChannel(channel)
        }

        notificationManager.notify(0, notificationBuilder.build())
    }

    private fun sendRegistrationToServer(token: String) {
        // TODO: Send token to your server
    }
}
