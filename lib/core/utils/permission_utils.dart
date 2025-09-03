import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'app_logger.dart';

class PermissionUtils {
  /// Request storage permissions
  Future<bool> requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), we need different permissions
        if (await _isAndroid13OrHigher()) {
          final status = await perm.Permission.manageExternalStorage.request();
          return status.isGranted;
        } else {
          // For older Android versions
          final status = await perm.Permission.storage.request();
          return status.isGranted;
        }
      } else if (Platform.isIOS) {
        // iOS doesn't require explicit storage permission for app documents
        return true;
      } else {
        // Desktop platforms don't require permission
        return true;
      }
    } catch (e) {
      AppLogger.error('Error requesting storage permission', e);
      return false;
    }
  }

  /// Check if storage permission is granted
  Future<bool> hasStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        if (await _isAndroid13OrHigher()) {
          final status = await Permission.manageExternalStorage.status;
          return status.isGranted;
        } else {
          final status = await Permission.storage.status;
          return status.isGranted;
        }
      } else {
        return true; // iOS and desktop don't need explicit permission
      }
    } catch (e) {
      AppLogger.error('Error checking storage permission', e);
      return false;
    }
  }

  /// Request camera permission (for taking photos to upload)
  Future<bool> requestCameraPermission() async {
    try {
      final status = await perm.Permission.camera.request();
      return status.isGranted;
    } catch (e) {
      AppLogger.error('Error requesting camera permission', e);
      return false;
    }
  }

  /// Check if camera permission is granted
  Future<bool> hasCameraPermission() async {
    try {
      final status = await perm.Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      AppLogger.error('Error checking camera permission', e);
      return false;
    }
  }

  /// Open app settings for manual permission grant
  Future<void> openAppSettings() async {
    try {
      await perm.openAppSettings();
    } catch (e) {
      AppLogger.error('Error opening app settings', e);
    }
  }

  /// Check if Android version is 13 or higher
  Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;

    // This is a simplified check. In a real app, you might want to use
    // device_info_plus package for more accurate version detection
    try {
      final result = await Process.run('getprop', ['ro.build.version.sdk']);
      final sdkVersion = int.tryParse(result.stdout.toString().trim()) ?? 0;
      return sdkVersion >= 33; // Android 13 is API level 33
    } catch (e) {
      AppLogger.error('Error checking Android version', e);
      return false;
    }
  }

  /// Request all necessary permissions at once
  Future<Map<perm.Permission, perm.PermissionStatus>> requestAllPermissions() async {
    final permissions = <perm.Permission>[];

    if (Platform.isAndroid) {
      if (await _isAndroid13OrHigher()) {
        permissions.addAll([
          perm.Permission.manageExternalStorage,
          perm.Permission.camera,
        ]);
      } else {
        permissions.addAll([perm.Permission.storage, perm.Permission.camera]);
      }
    } else if (Platform.isIOS) {
      permissions.addAll([perm.Permission.photos, perm.Permission.camera]);
    }

    if (permissions.isEmpty) {
      return {};
    }

    try {
      return await permissions.request();
    } catch (e) {
      AppLogger.error('Error requesting permissions', e);
      return {};
    }
  }
}
