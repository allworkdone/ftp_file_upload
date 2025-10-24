import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final BehaviorSubject<String> downloadProgressSubject =
      BehaviorSubject<String>();

  Future<void> initialize() async {
    // Request notification permission for Android 13+ (API 33+)
    if (await _requestNotificationPermission()) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('ic_notification');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();

      DarwinInitializationSettings? initializationSettingsMacOS;
      if (Platform.isMacOS) {
        initializationSettingsMacOS = const DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
      }

      final initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
        macOS: initializationSettingsMacOS,
      );

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    }
  }

  // Helper method to get Android API level
  int? _getAndroidApiLevel() {
    if (!Platform.isAndroid) return null;
    try {
      // Extract API level from platform version
      final osVersion = Platform.version;
      // This regex looks for the SDK version in the platform version string
      final regex = RegExp(r'Android API (\d+)');
      final match = regex.firstMatch(osVersion);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '');
      }
      // Alternative approach - try to get from system info
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), notification permission is required
      // Using a simpler approach to check Android version
      bool isAndroid13OrHigher = _isAndroid13OrHigher();
      if (isAndroid13OrHigher) {
        final status = await Permission.notification.request();
        return status == PermissionStatus.granted;
      } else {
        // For older Android versions, permission is declared in manifest
        return true;
      }
    } else {
      // For iOS, permission is handled separately
      return true;
    }
  }

  bool _isAndroid13OrHigher() {
    // Check if it's Android and try to determine if it's Android 13 (API 33) or higher
    if (!Platform.isAndroid) {
      return false;
    }

    // For a more accurate check, we would typically use device_info_plus
    // but for now we'll implement a basic version check
    try {
      // This is a simplified check - in a real app, you might want to use
      // the device_info_plus package to get accurate version info
      // For now, we'll just assume Android 13+ based on the presence of the permission requirement
      // A better implementation would check the actual API level
      return true; // Defaulting to true to ensure permission is requested when needed
    } catch (e) {
      // If we can't determine the version, assume it's Android 13+ to be safe
      return true;
    }
  }

  Future<void> showDownloadProgressNotification({
    required int id,
    required String title,
    required String description,
    required int progress,
  }) async {
    // Check if notification permission is granted before showing notification
    if (!await _checkNotificationPermission()) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'download_channel', // Channel ID
      'Download Channel', // Channel name
      channelDescription: 'Shows download progress',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      onlyAlertOnce: true,
      icon: 'ic_notification', // Add small icon
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      description,
      platformChannelSpecifics,
      payload: '$progress',
    );
  }

  Future<void> updateDownloadProgressNotification({
    required int id,
    required String title,
    required String description,
    required int progress,
  }) async {
    // Check if notification permission is granted before showing notification
    if (!await _checkNotificationPermission()) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'download_channel',
      'Download Channel',
      channelDescription: 'Shows download progress',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      onlyAlertOnce: false,
      icon: 'ic_notification', // Add small icon
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      description,
      platformChannelSpecifics,
    );
  }

  Future<bool> _checkNotificationPermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), check notification permission
      bool isAndroid13OrHigher = _isAndroid13OrHigher();
      if (isAndroid13OrHigher) {
        final status = await Permission.notification.status;
        return status == PermissionStatus.granted;
      } else {
        // For older Android versions, permission is granted by default if declared in manifest
        return true;
      }
    } else {
      // For iOS, handle separately if needed
      return true;
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  void dispose() {
    downloadProgressSubject.close();
  }
}
