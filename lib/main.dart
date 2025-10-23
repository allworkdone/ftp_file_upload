import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app/app.dart';
import 'core/di/injection.dart';
import 'core/services/notification_service.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/permission_utils.dart';

/// Request notification permissions
Future<void> _requestNotificationPermission() async {
  try {
    // For Android, permissions are declared in AndroidManifest.xml
    // For iOS, we need to request notification permissions
    if (Platform.isIOS) {
      await NotificationService().flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  } catch (e) {
    AppLogger.error('Error requesting notification permission', e);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging
  AppLogger.init();

  try {
    // Initialize Hive for local storage
    await Hive.initFlutter();

    // Initialize dependency injection
    await configureDependencies();

    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Initialize notification service
    await NotificationService().initialize();

    // Request necessary permissions at startup
    final permissionUtils = PermissionUtils();
    await permissionUtils.requestStoragePermission();
    await _requestNotificationPermission();

    AppLogger.info('App initialization completed successfully');

    runApp(const ProviderScope(child: FTPManagerApp()));
  } catch (error, stackTrace) {
    AppLogger.error('App initialization failed', error, stackTrace);
    runApp(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true, // Enable Material 3
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'App Failed to Initialize',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
