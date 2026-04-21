import 'package:flutter/services.dart';

class PlatformService {
  static const MethodChannel _channel = MethodChannel('screen_usage_channel');
  static const EventChannel _eventChannel = EventChannel('foreground_app_channel');

  static Future<bool> checkUsagePermission() async {
    try {
      final bool result = await _channel.invokeMethod('checkUsagePermission');
      return result;
    } catch (e) {
      print("Error checking permission: $e");
      return false;
    }
  }

  static Future<void> openUsageSettings() async {
    try {
      await _channel.invokeMethod('openUsageSettings');
    } catch (e) {
      print("Error opening settings: $e");
    }
  }

  static Future<List<dynamic>> getUsageStats() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getUsageStats');
      return result;
    } catch (e) {
      print("Error getting usage stats: $e");
      return [];
    }
  }

  static Stream<dynamic> getForegroundAppStream() {
    try {
      return _eventChannel.receiveBroadcastStream();
    } catch (e) {
      print("Error getting foreground app stream: $e");
      return const Stream.empty();
    }
  }

  static Future<void> startMonitoringService() async {
    try {
      await _channel.invokeMethod('startService');
      print("Monitoring service started");
    } catch (e) {
      print("Error starting service: $e");
    }
  }
}