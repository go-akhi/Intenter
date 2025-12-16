package com.example.intenter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class UnlockReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Intent.ACTION_BOOT_COMPLETED == intent.action || "android.intent.action.QUICKBOOT_POWERON" == intent.action) {
            val serviceIntent = Intent(context, IntenterService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } else if (Intent.ACTION_USER_PRESENT == intent.action) {
            Log.d("UnlockReceiver", "Device unlocked. Launching Intenter Prompt.")
            val launchIntent = Intent(context, MainActivity::class.java)
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            launchIntent.putExtra("from_unlock", true)
            context.startActivity(launchIntent)
        } else if (Intent.ACTION_SCREEN_OFF == intent.action) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putLong("flutter.last_lock_timestamp", System.currentTimeMillis()).apply()
            Log.d("UnlockReceiver", "Screen off. Saved timestamp.")
        }
    }
}
