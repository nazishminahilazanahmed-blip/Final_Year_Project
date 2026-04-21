package com.example.mood_sync_working

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val CHANNEL = "screen_usage_channel"
    private val EVENT_CHANNEL = "foreground_app_channel"
    private var eventSink: EventChannel.EventSink? = null
    private val TAG = "MainActivity"
    private var scheduler: ScheduledExecutorService? = null
    private var lastPackage = ""

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Request Notification Permission for Android 13+
        requestNotificationPermission()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkUsagePermission" -> result.success(checkUsagePermission())
                    "openUsageSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "getUsageStats" -> result.success(getUsageStats())
                    "startService" -> {
                        startMonitoringService()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startForegroundAppMonitoring()
                }
                override fun onCancel(arguments: Any?) {
                    stopForegroundAppMonitoring()
                    eventSink = null
                }
            })
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }
    }

    private fun checkUsagePermission(): Boolean {
        val usageStatsManager = getSystemService(USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
        val currentTime = System.currentTimeMillis()
        val stats = usageStatsManager.queryUsageStats(
            android.app.usage.UsageStatsManager.INTERVAL_DAILY,
            currentTime - 1000 * 3600 * 24,
            currentTime
        )
        return stats != null && stats.isNotEmpty()
    }

    private fun getUsageStats(): List<Map<String, Any>> {
        val usageStatsList = mutableListOf<Map<String, Any>>()
        try {
            val usageStatsManager = getSystemService(USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
            val endTime = System.currentTimeMillis()
            val startTime = endTime - 1000 * 3600 * 24 * 7
            val stats = usageStatsManager.queryUsageStats(android.app.usage.UsageStatsManager.INTERVAL_DAILY, startTime, endTime)

            val appUsageMap = mutableMapOf<String, Long>()
            stats?.forEach { usageStats ->
                val packageName = usageStats.packageName
                val totalTime = usageStats.totalTimeInForeground
                if (totalTime > 0 && packageName != null) {
                    appUsageMap[packageName] = appUsageMap.getOrDefault(packageName, 0) + totalTime
                }
            }
            appUsageMap.forEach { (packageName, totalTime) ->
                usageStatsList.add(mapOf("packageName" to packageName, "timeInForeground" to totalTime))
            }
            usageStatsList.sortByDescending { it["timeInForeground"] as Long }
        } catch (e: Exception) {
            Log.e(TAG, "Error: ${e.message}")
        }
        return usageStatsList
    }

    private fun startMonitoringService() {
        try {
            val serviceIntent = Intent(this, ScreenMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error: ${e.message}")
        }
    }

    private fun startForegroundAppMonitoring() {
        stopForegroundAppMonitoring()
        scheduler = Executors.newSingleThreadScheduledExecutor()
        scheduler?.scheduleAtFixedRate({ checkForegroundApp() }, 0, 2, TimeUnit.SECONDS)
    }

    private fun stopForegroundAppMonitoring() {
        scheduler?.shutdownNow()
        scheduler = null
    }

    private fun checkForegroundApp() {
        try {
            val usageStatsManager = getSystemService(USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
            val endTime = System.currentTimeMillis()
            val startTime = endTime - 5000
            val stats = usageStatsManager.queryUsageStats(android.app.usage.UsageStatsManager.INTERVAL_DAILY, startTime, endTime)

            var currentPackage = ""
            var maxTime = 0L
            stats?.forEach { usageStats ->
                if (usageStats.totalTimeInForeground > maxTime) {
                    maxTime = usageStats.totalTimeInForeground
                    currentPackage = usageStats.packageName
                }
            }

            if (currentPackage.isNotEmpty() && currentPackage != lastPackage) {
                lastPackage = currentPackage
                val appName = getAppName(currentPackage)
                runOnUiThread { eventSink?.success(appName) }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error: ${e.message}")
        }
    }

    private fun getAppName(packageName: String): String {
        val appNames = mapOf("com.whatsapp" to "WhatsApp", "com.instagram.android" to "Instagram")
        return appNames[packageName] ?: packageName.substringAfterLast(".")
    }

    override fun onDestroy() {
        stopForegroundAppMonitoring()
        super.onDestroy()
    }
}
