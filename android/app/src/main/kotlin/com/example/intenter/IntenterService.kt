package com.example.intenter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder

class IntenterService : Service() {
    private var unlockReceiver: UnlockReceiver? = null

    override fun onBind(intent: Intent): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        startForegroundService()
        registerUnlockReceiver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterUnlockReceiver()
    }

    private fun startForegroundService() {
        val channelId = "intenter_service_channel"
        val channelName = "Intenter Service"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }

        val builder: Notification.Builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this)
        }

        val notification: Notification = builder
            .setContentTitle("Intenter Running")
            .setContentText("Listening for device unlocks")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()

        startForeground(1, notification)
    }



    private fun registerUnlockReceiver() {
        unlockReceiver = UnlockReceiver()
        val filter = IntentFilter()
        filter.addAction(Intent.ACTION_USER_PRESENT)
        filter.addAction(Intent.ACTION_SCREEN_OFF)
        registerReceiver(unlockReceiver, filter)
    }

    private fun unregisterUnlockReceiver() {
        unlockReceiver?.let {
            unregisterReceiver(it)
            unlockReceiver = null
        }
    }
}
