import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/platform_service.dart';
import 'stats_screen.dart';
import 'dart:async';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> usageList = [];
  String currentApp = "No app detected";
  String status = "Checking permission...";
  bool isMonitoring = false;
  bool notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkPermission();
    _listenToForegroundApp();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      notificationsEnabled = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? 'Notifications enabled ✅' : 'Notifications disabled ❌')),
    );
  }

  Future<void> _checkPermission() async {
    try {
      setState(() {
        status = "Checking permission...";
      });

      bool granted = await PlatformService.checkUsagePermission();

      if (granted) {
        setState(() {
          status = "Permission Granted ✅";
        });
        await _loadUsageStats();
      } else {
        setState(() {
          status = "Required Permission" ❌ - Tap 'Grant Access'";
        });
      }
    } catch (e) {
      setState(() {
        status = "Error checking permission";
      });
    }
  }

  Future<void> _loadUsageStats() async {
    try {
      setState(() {
        status = "Loading usage data...";
      });

      List<dynamic> data = await PlatformService.getUsageStats();

      List<Map<String, dynamic>> formattedData = [];
      for (var app in data) {
        formattedData.add({
          'packageName': app['packageName'] ?? 'Unknown',
          'appName': _getAppName(app['packageName'] ?? ''),
          'timeInForeground': app['timeInForeground'] ?? 0,
        });
      }

      formattedData.sort((a, b) => b['timeInForeground'].compareTo(a['timeInForeground']));

      setState(() {
        usageList = formattedData;
        if (formattedData.isEmpty) {
          status = "No usage data yet. Use your phone normally.";
        } else {
          status = "✅ ${formattedData.length} apps loaded";
        }
      });
    } catch (e) {
      setState(() {
        status = "Error loading data";
      });
    }
  }

  String _getAppName(String packageName) {
    Map<String, String> appNames = {
      'com.whatsapp': 'WhatsApp',
      'com.instagram.android': 'Instagram',
      'com.facebook.katana': 'Facebook',
      'com.youtube.android': 'YouTube',
      'com.android.chrome': 'Chrome',
      'com.spotify.music': 'Spotify',
      'com.snapchat.android': 'Snapchat',
      'com.tiktok.android': 'TikTok',
    };

    for (var entry in appNames.entries) {
      if (packageName.contains(entry.key)) {
        return entry.value;
      }
    }
    return packageName.split('.').last;
  }

  void _listenToForegroundApp() {
    PlatformService.getForegroundAppStream().listen((event) {
      if (event != null && event.toString().isNotEmpty) {
        setState(() {
          currentApp = event.toString();
        });
        print("✅ Current app updated: $currentApp");
      }
    }, onError: (error) {
      print("Error listening to foreground app: $error");
    });
  }

  Future<void> _openSettings() async {
    await PlatformService.openUsageSettings();
  }

  Future<void> _startMonitoring() async {
    try {
      setState(() {
        status = "Starting monitoring...";
      });

      bool granted = await PlatformService.checkUsagePermission();

      if (!granted) {
        setState(() {
          status = "Please grant permission first ❌";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please grant usage access permission first')),
        );
        await _openSettings();
        return;
      }

      await PlatformService.startMonitoringService();

      setState(() {
        isMonitoring = true;
        status = "Monitoring Started ✅";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monitoring started! You will receive wellness reminders.')),
      );

      // Auto refresh every 30 seconds when monitoring
      if (isMonitoring) {
        Timer.periodic(const Duration(seconds: 30), (timer) {
          if (mounted && isMonitoring) {
            _loadUsageStats();
          } else {
            timer.cancel();
          }
        });
      }

      await _loadUsageStats();

    } catch (e) {
      setState(() {
        status = "Error starting monitoring";
      });
    }
  }

  String formatTime(int milliseconds) {
    int hours = (milliseconds / (1000 * 60 * 60)).truncate();
    int minutes = ((milliseconds % (1000 * 60 * 60)) / (1000 * 60)).truncate();

    if (hours > 0) {
      return "$hours hr $minutes min";
    } else {
      return "$minutes min";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mood Sync"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StatsScreen(data: usageList),
                ),
              );
            },
            tooltip: 'View Statistics',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsageStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Card(
                color: status.contains("✅") ? Colors.green.shade50
                    : status.contains("❌") ? Colors.red.shade50
                    : Colors.deepPurple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        status.contains("✅") ? Icons.check_circle
                            : status.contains("❌") ? Icons.error
                            : Icons.info,
                        color: status.contains("✅") ? Colors.green
                            : status.contains("❌") ? Colors.red
                            : Colors.deepPurple,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          status,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: status.contains("✅") ? Colors.green.shade800
                                : status.contains("❌") ? Colors.red.shade800
                                : Colors.deepPurple.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Current App Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Currently Using",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.phone_android, color: Colors.deepPurple, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              currentApp,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isMonitoring)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(Icons.fiber_manual_record, size: 12, color: Colors.green),
                              SizedBox(width: 4),
                              Text("Monitoring Active", style: TextStyle(color: Colors.green, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _checkPermission,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Check Permission"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings),
                      label: const Text("Grant Access"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Notification Toggle
              Card(
                color: notificationsEnabled ? Colors.deepPurple.shade50 : Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                            color: notificationsEnabled ? Colors.deepPurple : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Wellness Notifications",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: notificationsEnabled ? Colors.deepPurple.shade800 : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                notificationsEnabled ? "Prayer, Hydration & 1 hour reminders" : "Reminders are off",
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: notificationsEnabled,
                        onChanged: _toggleNotifications,
                        activeThumbColor: Colors.deepPurple,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isMonitoring ? null : _startMonitoring,
                  icon: Icon(isMonitoring ? Icons.check_circle : Icons.play_circle_outline),
                  label: Text(isMonitoring ? "Monitoring Started" : "Start Monitoring"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMonitoring ? Colors.green : Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // App Usage List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "App Usage",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: _loadUsageStats,
                    child: const Text("Refresh"),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              if (usageList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.analytics_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          "No app usage data yet",
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Use your phone normally,\nthen tap Refresh",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: usageList.length,
                  itemBuilder: (context, index) {
                    final app = usageList[index];
                    final timeInForeground = app['timeInForeground'] ?? 0;
                    final minutes = (timeInForeground / 60000).round();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.withOpacity(0.1),
                          child: Text(
                            (index + 1).toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                          ),
                        ),
                        title: Text(
                          app['appName'] ?? app['packageName'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          app['packageName'] ?? '',
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatTime(timeInForeground),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.deepPurple,
                              ),
                            ),
                            Text(
                              '$minutes minutes',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}