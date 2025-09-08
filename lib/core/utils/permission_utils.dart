import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'app_logger.dart';

class PermissionUtils {
  /// Request storage permissions (updated for modern Android)
  Future<bool> requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        final androidVersion = await _getAndroidApiLevel();

        if (androidVersion >= 33) {
          // Android 13+ (API 33+): Use granular media permissions
          final results = await [
            perm.Permission.photos,
            perm.Permission.videos,
            perm.Permission.audio,
          ].request();

          // Check if at least one media permission is granted
          return results.values.any((status) => status.isGranted);
        } else if (androidVersion >= 30) {
          // Android 11-12 (API 30-32): Request storage permission
          // MANAGE_EXTERNAL_STORAGE cannot be requested via normal flow
          final status = await perm.Permission.storage.request();
          return status.isGranted;
        } else {
          // Android 10 and below (API < 30)
          final status = await perm.Permission.storage.request();
          return status.isGranted;
        }
      } else if (Platform.isIOS) {
        // iOS: Request photos permission
        final status = await perm.Permission.photos.request();
        return status.isGranted;
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
        final androidVersion = await _getAndroidApiLevel();

        if (androidVersion >= 33) {
          // Android 13+: Check granular media permissions
          final photoStatus = await perm.Permission.photos.status;
          final videoStatus = await perm.Permission.videos.status;
          final audioStatus = await perm.Permission.audio.status;

          return photoStatus.isGranted ||
              videoStatus.isGranted ||
              audioStatus.isGranted;
        } else if (androidVersion >= 30) {
          // Android 11-12: Check storage permission
          final status = await perm.Permission.storage.status;
          return status.isGranted;
        } else {
          // Android 10 and below
          final status = await perm.Permission.storage.status;
          return status.isGranted;
        }
      } else if (Platform.isIOS) {
        final status = await perm.Permission.photos.status;
        return status.isGranted;
      } else {
        return true; // Desktop platforms don't need explicit permission
      }
    } catch (e) {
      AppLogger.error('Error checking storage permission', e);
      return false;
    }
  }

  /// Request camera permission
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

  /// Get Android API level
  Future<int> _getAndroidApiLevel() async {
    if (!Platform.isAndroid) return 0;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt;
    } catch (e) {
      AppLogger.error('Error getting Android API level', e);
      return 0;
    }
  }

  /// Request appropriate permissions based on Android version
  Future<Map<perm.Permission, perm.PermissionStatus>>
      requestAllPermissions() async {
    final permissions = <perm.Permission>[];

    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidApiLevel();

      if (androidVersion >= 33) {
        // Android 13+: Request granular media permissions
        permissions.addAll([
          perm.Permission.photos,
          perm.Permission.videos,
          perm.Permission.audio,
          perm.Permission.camera,
        ]);
      } else {
        // Android 12 and below
        permissions.addAll([
          perm.Permission.storage,
          perm.Permission.camera,
        ]);
      }
    } else if (Platform.isIOS) {
      permissions.addAll([
        perm.Permission.photos,
        perm.Permission.camera,
      ]);
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

  /// Check if we need to show rationale for permissions
  Future<bool> shouldShowStoragePermissionRationale() async {
    if (!Platform.isAndroid) return false;

    try {
      final androidVersion = await _getAndroidApiLevel();

      if (androidVersion >= 33) {
        return await perm.Permission.photos.shouldShowRequestRationale;
      } else {
        return await perm.Permission.storage.shouldShowRequestRationale;
      }
    } catch (e) {
      return false;
    }
  }
}
