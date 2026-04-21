package com.example.mood_sync_working

import android.app.*
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Calendar
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class ScreenMonitorService : Service() {
    private val START_CHANNEL_ID = "start_channel"
    private val WELLNESS_CHANNEL_ID = "wellness_channel"
    private val PRAYER_CHANNEL_ID = "prayer_channel"
    private val HYDRATION_CHANNEL_ID = "hydration_channel"
    private val LATE_NIGHT_CHANNEL_ID = "late_night_channel"
    private val PERSISTENT_CHANNEL_ID = "persistent_channel"

    private val PERSISTENT_NOTIFICATION_ID = 1001
    private val TAG = "ScreenMonitorService"

    private var continuousStartTime = System.currentTimeMillis()
    private var lastAppPackage = ""
    private val handler = Handler(Looper.getMainLooper())
    private var scheduler: ScheduledExecutorService? = null

    // Initialize with current time so they don't all trigger at 0
    private var lastHourReminder = System.currentTimeMillis()
    private var lastHydrationReminder = System.currentTimeMillis()
    private var lastPrayerReminder = 0L // Keep 0 so first prayer of the day shows
    private var lastLateNightReminder = System.currentTimeMillis()
    private var lastWellnessReminder = System.currentTimeMillis()

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service Created")
        createNotificationChannels()
        startForeground(PERSISTENT_NOTIFICATION_ID, createPersistentNotification())
        startAllMonitors()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channels = listOf(
                NotificationChannel(START_CHANNEL_ID, "Start Notifications", NotificationManager.IMPORTANCE_HIGH),
                NotificationChannel(WELLNESS_CHANNEL_ID, "Wellness Reminders", NotificationManager.IMPORTANCE_HIGH),
                NotificationChannel(PRAYER_CHANNEL_ID, "Prayer Reminders", NotificationManager.IMPORTANCE_HIGH),
                NotificationChannel(HYDRATION_CHANNEL_ID, "Hydration Reminders", NotificationManager.IMPORTANCE_HIGH),
                NotificationChannel(LATE_NIGHT_CHANNEL_ID, "Late Night Alerts", NotificationManager.IMPORTANCE_HIGH),
                NotificationChannel(PERSISTENT_CHANNEL_ID, "Screen Monitor", NotificationManager.IMPORTANCE_LOW)
            )
            channels.forEach { manager.createNotificationChannel(it) }
        }
    }

    private fun createPersistentNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, PERSISTENT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setContentTitle("🧘 Mood Sync Active")
            .setContentText("Monitoring screen usage...")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun startAllMonitors() {
        sendStartNotification()
        scheduler = Executors.newSingleThreadScheduledExecutor()
        
        // Check app usage every 5 seconds
        scheduler?.scheduleAtFixedRate({
            try {
                checkContinuousAppUsage()
            } catch (e: Exception) {
                Log.e(TAG, "Usage check error: ${e.message}")
            }
        }, 5, 5, TimeUnit.SECONDS)

        // Periodic checks for wellness/hydration/prayer every 1 minute
        handler.post(object : Runnable {
            override fun run() {
                val now = System.currentTimeMillis()
                checkPrayerTimes()
                checkHydration(now)
                checkLateNight(now)
                checkWellnessReminder(now)
                handler.postDelayed(this, 60000)
            }
        })
    }

    private fun sendStartNotification() {
        val notification = NotificationCompat.Builder(this, START_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setContentTitle("✅ Monitoring Started")
            .setContentText("Wellness tracking is now active.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(2000, notification)
    }

    private fun checkContinuousAppUsage() {
        val currentApp = getCurrentForegroundApp()
        val now = System.currentTimeMillis()
        if (currentApp.isNotEmpty()) {
            if (currentApp == lastAppPackage) {
                val continuousMinutes = (now - continuousStartTime) / (1000 * 60)
                if (continuousMinutes >= 60 && (now - lastHourReminder) >= 3600000) {
                    sendWellnessNotification("🎯 1 Hour Break", "Time to stretch!", WELLNESS_CHANNEL_ID)
                    lastHourReminder = now
                }
            } else {
                lastAppPackage = currentApp
                continuousStartTime = now
            }
        }
    }

    private fun checkWellnessReminder(now: Long) {
        // Reduced to 60 mins for better visibility, initial trigger fixed
        if ((now - lastWellnessReminder) >= 60 * 60 * 1000) {
            val messages = listOf("🧘 Take a deep breath", "🪑 Do a quick desk stretch")
            sendWellnessNotification("🧘 Wellness", messages.random(), WELLNESS_CHANNEL_ID)
            lastWellnessReminder = now
        }
    }

    private fun checkHydration(now: Long) {
        if ((now - lastHydrationReminder) >= 45 * 60 * 1000) {
            sendWellnessNotification("💧 Hydration", "Drink a glass of water!", HYDRATION_CHANNEL_ID)
            lastHydrationReminder = now
        }
    }

    private fun checkPrayerTimes() {
        val calendar = Calendar.getInstance()
        val hour = calendar.get(Calendar.HOUR_OF_DAY)
        val minute = calendar.get(Calendar.MINUTE)
        val prayers = listOf(
            PrayerTime("Fajr", 4, 30), PrayerTime("Dhuhr", 12, 15),
            PrayerTime("Asr", 17, 0), PrayerTime("Maghrib", 18, 30), PrayerTime("Isha", 19, 45)
        )
        for (prayer in prayers) {
            if (hour == prayer.hour && minute == prayer.minute) {
                if ((System.currentTimeMillis() - lastPrayerReminder) > 60000) {
                    sendWellnessNotification("🕌 Prayer Time", "${prayer.name} time has started.", PRAYER_CHANNEL_ID)
                    lastPrayerReminder = System.currentTimeMillis()
                }
            }
        }
    }

    private fun checkLateNight(now: Long) {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        if ((hour >= 23 || hour <= 5) && (now - lastLateNightReminder) >= 3600000) {
            sendWellnessNotification("🌙 Late Night", "Time to wind down for sleep?", LATE_NIGHT_CHANNEL_ID)
            lastLateNightReminder = now
        }
    }

    private fun sendWellnessNotification(title: String, message: String, channelId: String) {
        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify((System.currentTimeMillis() % 10000).toInt(), notification)
    }

    private fun getCurrentForegroundApp(): String {
        return try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 10000, now)
            stats?.maxByOrNull { it.totalTimeInForeground }?.packageName ?: ""
        } catch (e: Exception) { "" }
    }

    private fun getAppName(packageName: String): String = packageName.substringAfterLast(".")

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        scheduler?.shutdownNow()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    data class PrayerTime(val name: String, val hour: Int, val minute: Int)
}
