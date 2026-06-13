package com.vividmemories.dotclash

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Challenge invites",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Friend challenge invites"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
        super.onCreate(savedInstanceState)
    }

    companion object {
        const val CHANNEL_ID = "dot_clash_challenges"
    }
}
