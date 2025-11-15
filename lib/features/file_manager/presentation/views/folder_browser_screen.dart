import 'dart:async';
import 'dart:io' show Directory, File, Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_upload/core/services/notification_service.dart';
import 'package:file_upload/core/utils/app_logger.dart';
import 'package:file_upload/core/utils/permission_utils.dart';
import 'package:file_upload/features/authentication/presentation/viewmodels/auth_viewmodel.dart';
import 'package:file_upload/features/file_manager/domain/usecases/generate_link_usecase.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../file_manager/domain/entities/ftp_file.dart';
import '../../../file_manager/domain/entities/ftp_folder.dart';
import '../../../file_manager/domain/usecases/delete_file_usecase.dart';
import '../../../file_manager/domain/usecases/delete_folder_usecase.dart';
import '../../../file_manager/domain/usecases/rename_file_usecase.dart';
import '../../../file_manager/domain/usecases/rename_folder_usecase.dart';
import '../../../file_manager/domain/repositories/file_manager_repository.dart';
import '../viewmodels/folder_browser_viewmodel.dart';

class FolderBrowserScreen extends ConsumerStatefulWidget {
  final String folderPath;
  const FolderBrowserScreen({super.key, required this.folderPath});

  @override
  ConsumerState<FolderBrowserScreen> createState() =>
      _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends ConsumerState<FolderBrowserScreen> {
  // Track download progress for each file individually
  final Map<String, double> _downloadProgressMap = {};
  final Map<String, bool> _isDownloadingMap = {};
  final Map<String, String> _downloadingFileNameMap = {};
  final Map<String, VoidCallback?> _cancelDownloadMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(folderBrowserViewModelProvider.notifier).load(widget.folderPath);
    });
  }

  @override
  void didUpdateWidget(FolderBrowserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when the folder path changes
    if (oldWidget.folderPath != widget.folderPath) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(folderBrowserViewModelProvider.notifier).load(widget.folderPath);
      });
    }
 }

  Future<void> _deleteItem(String path, String name, bool isFolder) async {
    final confirmed = await _showDeleteDialog(name, isFolder);
    if (confirmed != true) return;

    try {
      if (isFolder) {
        await getIt<DeleteFolderUsecase>()(path);
      } else {
        await getIt<DeleteFileUsecase>()(path);
      }
      _showSnackBar('$name deleted successfully', isSuccess: true);
      // Reload the current folder
      ref.read(folderBrowserViewModelProvider.notifier).load(widget.folderPath);
    } catch (e) {
      _showSnackBar('Failed to delete: $e', isSuccess: false);
    }
  }

  Future<bool?> _showDeleteDialog(String name, bool isFolder) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title: Text('Delete ${isFolder ? 'Folder' : 'File'}',
            style: const TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "$name"?\n\nThis action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

// Show rationale dialog explaining why permission is needed
  Future<bool> _showPermissionRationaleDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.darkSurface.withOpacity(0.9),
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'Storage Access Needed',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'This app needs access to your device storage to download and save files. This allows you to access downloaded files from your file manager.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showPermissionDeniedDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.darkSurface.withOpacity(0.9),
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'Permission Required',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Storage permission was denied. To download files, please enable storage/media permissions in app settings.\n\nGo to: Settings > Apps > [Your App Name] > Permissions',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _downloadFile(FTPFile file) async {
    try {
      // Reset progress for this specific file
      setState(() {
        _downloadProgressMap[file.fullPath] = 0.0;
        _isDownloadingMap[file.fullPath] = true;
        _downloadingFileNameMap[file.fullPath] = file.name;
      });

      // Get notification service from dependency injection
      final notificationService = getIt<NotificationService>();

      // Show initial notification - wrap in try-catch to handle potential notification issues
      try {
        await notificationService.showDownloadProgressNotification(
          id: file.hashCode, // Unique ID for this download
          title: 'Downloading ${file.name}',
          description: 'Starting download...',
          progress: 0,
        );
      } catch (e) {
        AppLogger.warning('Could not show download notification: $e');
      }

      // For Android, check and request appropriate permissions
      if (Platform.isAndroid) {
        final permissionUtils = PermissionUtils();

        final hasPermission = await permissionUtils.hasStoragePermission();

        if (!hasPermission) {
          final shouldShowRationale =
              await permissionUtils.shouldShowStoragePermissionRationale();

          if (shouldShowRationale) {
            final userWantsToGrant = await _showPermissionRationaleDialog();
            if (!userWantsToGrant) {
              setState(() => _isDownloadingMap[file.fullPath] = false);
              await notificationService.cancelNotification(file.hashCode);
              return;
            }
          }

          final granted = await permissionUtils.requestStoragePermission();

          if (!granted) {
            setState(() => _isDownloadingMap[file.fullPath] = false);
            await notificationService.cancelNotification(file.hashCode);
            _showSnackBar('Storage permission is required to download files',
                isSuccess: false);

            final shouldOpenSettings = await _showPermissionDeniedDialog();
            if (shouldOpenSettings) {
              await permissionUtils.openAppSettings();
            }
            return;
          }
        }
      }

      // Get credentials from auth
      final auth = ref.read(authViewModelProvider);
      if (auth.credentials == null) {
        setState(() => _isDownloadingMap[file.fullPath] = false);
        await notificationService.cancelNotification(file.hashCode);
        _showSnackBar('No FTP credentials available', isSuccess: false);
        return;
      }

      // Get temporary directory for download
      final tempDir = Directory.systemTemp;
      final tempPath = tempDir.path;

      // Create a completer for cancellation
      final cancelCompleter = Completer<void>();

      // Store the cancel function in the map
      _cancelDownloadMap[file.fullPath] = () {
        if (!cancelCompleter.isCompleted) {
          cancelCompleter.complete();
        }
      };

      // Use repository with progress callback and cancellation
      final localFilePath = await getIt<FileManagerRepository>().downloadFile(
        file.fullPath,
        tempPath,
        onProgress: (progress) {
          // Check if cancellation was requested
          if (cancelCompleter.isCompleted) {
            return; // Stop updating progress if cancelled
          }

          // Check if widget is still mounted before calling setState
          if (!mounted) return;

          final intProgress = (progress * 100).toInt();
          setState(() {
            _downloadProgressMap[file.fullPath] = progress;
          });

          // Update notification with progress
          try {
            notificationService.updateDownloadProgressNotification(
              id: file.hashCode,
              title: 'Downloading ${file.name}',
              description: '${intProgress}% complete',
              progress: intProgress,
            );
          } catch (e) {
            AppLogger.warning('Could not update download notification: $e');
          }
        },
        onCancel: () {
          if (!cancelCompleter.isCompleted) {
            cancelCompleter.complete();
          }
        },
      );

      // Check if the download was cancelled
      if (cancelCompleter.isCompleted) {
        if (mounted) {
          setState(() => _isDownloadingMap[file.fullPath] = false);
        }
        try {
          await notificationService.showDownloadProgressNotification(
            id: file.hashCode,
            title: 'Download cancelled',
            description: '${file.name} download was cancelled',
            progress: 10,
          );
        } catch (e) {
          AppLogger.warning('Could not show cancelled notification: $e');
        }
        Future.delayed(Duration(seconds: 2), () async {
          try {
            await notificationService.cancelNotification(file.hashCode);
          } catch (e) {
            AppLogger.warning('Could not cancel notification: $e');
          }
        });
        if (mounted) {
          _showSnackBar('Download cancelled', isSuccess: false);
        }
        return;
      }

      // Read the downloaded file
      final downloadedFile = File(localFilePath);
      final bytes = await downloadedFile.readAsBytes();

      // Save to Downloads folder using the improved method
      final savedFilePath = await _saveToDownloads(file.name, bytes);

      if (savedFilePath != null) {
        // Clean up temp file
        try {
          await downloadedFile.delete();
        } catch (e) {
          AppLogger.error('Could not clean up temp file', e);
        }

        // Complete progress for this file
        if (mounted) {
          setState(() => _downloadProgressMap[file.fullPath] = 1.0);
        }

        // Update notification to completed
        try {
          await notificationService.showDownloadProgressNotification(
            id: file.hashCode,
            title: 'Download completed',
            description: '${file.name} saved successfully',
            progress: 100,
          );
        } catch (e) {
          AppLogger.warning('Could not show completed notification: $e');
        }

        // Small delay to show 10%
        await Future.delayed(Duration(milliseconds: 500));

        // Mark as not downloading anymore
        if (mounted) {
          setState(() => _isDownloadingMap[file.fullPath] = false);
        }

        // Remove the cancel function from the map
        _cancelDownloadMap.remove(file.fullPath);

        // Cancel the notification after a short delay
        Future.delayed(Duration(seconds: 5), () async {
          try {
            await notificationService.cancelNotification(file.hashCode);
          } catch (e) {
            AppLogger.warning('Could not cancel completed notification: $e');
          }
        });

        if (mounted) {
          _showSnackBar('Download completed successfully!', isSuccess: true);
        }

        // Show download complete dialog
        if (mounted) {
          _showDownloadCompleteDialog(savedFilePath);
        }
      } else {
        // Show error notification
        await notificationService.showDownloadProgressNotification(
          id: file.hashCode,
          title: 'Download failed',
          description: 'Failed to save ${file.name}',
          progress: 10,
        );
        Future.delayed(Duration(seconds: 3), () {
          notificationService.cancelNotification(file.hashCode);
        });

        throw Exception('Failed to save file to Downloads folder');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloadingMap[file.fullPath] = false);
      }
      // Remove the cancel function from the map in case of error
      _cancelDownloadMap.remove(file.fullPath);
      AppLogger.error('Download failed', e);
      if (mounted) {
        _showSnackBar('Download failed: ${e.toString()}', isSuccess: false);
      }
    }
  }

// Widget to show download progress
  Widget _buildDownloadProgress() {
    // This method is no longer used since progress is shown directly on file items
    return SizedBox.shrink();
  }

  String _getProgressText(String filePath) {
    final progress = _downloadProgressMap[filePath] ?? 0.0;
    if (progress < 0.1) return 'Initializing...';
    if (progress < 0.3) return 'Connecting...';
    if (progress < 0.8) return 'Downloading...';
    if (progress < 0.9) return 'Saving file...';
    if (progress < 1.0) return 'Finalizing...';
    return 'Complete!';
  }

// Save file to Downloads folder with proper accessibility
  Future<String?> _saveToDownloads(String fileName, List<int> bytes) async {
    try {
      Directory? downloadsDir;

      if (Platform.isAndroid) {
        // Try multiple approaches for Android

        // Method 1: Try to get Downloads directory directly
        try {
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            downloadsDir = Directory('/storage/emulated/0/Downloads');
          }
        } catch (e) {
          AppLogger.error('Could not access Downloads via direct path', e);
        }

        // Method 2: Use path_provider as fallback
        if (downloadsDir == null || !await downloadsDir.exists()) {
          try {
            downloadsDir = await getDownloadsDirectory();
          } catch (e) {
            AppLogger.error(
                'Could not get Downloads directory via path_provider', e);
          }
        }

        // Method 3: Use external storage directory as final fallback
        if (downloadsDir == null || !await downloadsDir.exists()) {
          try {
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              downloadsDir =
                  Directory(path.join(externalDir.path, 'Downloads'));
              await downloadsDir.create(recursive: true);
            }
          } catch (e) {
            AppLogger.error(
                'Could not create Downloads in external storage', e);
          }
        }
      } else if (Platform.isIOS) {
        // For iOS, use Documents directory
        downloadsDir = await getApplicationDocumentsDirectory();
      } else {
        // For desktop, use Downloads directory
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Could not determine downloads directory');
      }

      // Ensure the directory exists
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Create unique filename if file already exists
      String finalFileName = fileName;
      int counter = 1;

      while (await File(path.join(downloadsDir.path, finalFileName)).exists()) {
        final nameWithoutExt = path.basenameWithoutExtension(fileName);
        final extension = path.extension(fileName);
        finalFileName = '${nameWithoutExt}_$counter$extension';
        counter++;
      }

      // Save the file
      final filePath = path.join(downloadsDir.path, finalFileName);
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // For Android, try to make the file visible in media scanner
      if (Platform.isAndroid) {
        await _notifyMediaScanner(filePath);
      }

      return filePath;
    } catch (e) {
      AppLogger.error('Error saving file to Downloads', e);

      // Final fallback: try using FileSaver
      try {
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(bytes),
          fileExtension: path.extension(fileName).replaceFirst('.', ''),
          mimeType: _getMimeType(path.extension(fileName)),
        );
        return 'FileSaver location'; // We don't know exact path with FileSaver
      } catch (e2) {
        AppLogger.error('FileSaver fallback also failed', e2);
        return null;
      }
    }
  }

// Notify Android's MediaScanner about the new file
  Future<void> _notifyMediaScanner(String filePath) async {
    try {
      if (Platform.isAndroid) {
        // Use platform channel to scan the file
        const platform = MethodChannel('com.allworkdone.upflow.media_scanner');
        await platform.invokeMethod('scanFile', {'path': filePath});
      }
    } catch (e) {
      // Ignore media scanner errors - file is still saved
      AppLogger.error('Could not notify media scanner', e);
    }
  }

// Show dialog with download location
  _showDownloadCompleteDialog(String filePath) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text(
              'Download Complete',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File saved successfully!',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Location:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Downloads folder',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.insert_drive_file,
                          color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'File:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    path.basename(filePath),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _copyFilePathToClipboard(filePath);
            },
            icon: Icon(Icons.copy, color: AppColors.primary, size: 18),
            label: Text(
              'Copy Path',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _openFileManagerAlternative();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: Icon(Icons.folder_open, size: 18),
            label: Text('Find File'),
          ),
        ],
      ),
    );
  }

// Alternative method to open file manager using system intents
  Future<void> _openFileManagerAlternative() async {
    if (Platform.isAndroid) {
      bool opened = false;

      // Method 1: Try to open Downloads in Files app using content URI
      try {
        final uri = Uri.parse(
            'content://com.android.externalstorage.documents/tree/primary%3ADownload');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          opened = true;
        }
      } catch (e) {
        print('Method 1 failed: $e');
      }

      if (!opened) {
        // Method 2: Try generic file manager intent
        try {
          final uri = Uri.parse('file:///storage/emulated/0/Download');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            opened = true;
          }
        } catch (e) {
          print('Method 2 failed: $e');
        }
      }

      if (!opened) {
        // Method 3: Open file picker which usually opens Downloads
        try {
          final uri = Uri.parse('content://media/external/file');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            opened = true;
          }
        } catch (e) {
          print('Method 3 failed: $e');
        }
      }

      if (!opened) {
        // If all methods fail, show help dialog
        _showFileManagerHelpDialog();
      }
    } else {
      // For iOS, open Files app
      try {
        final uri = Uri.parse('shareddocuments://');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        _showFileManagerHelpDialog();
      }
    }
  }

// Show help dialog with manual instructions
  Future<void> _showFileManagerHelpDialog() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceBrand = 'your device';

    if (Platform.isAndroid) {
      try {
        final androidInfo = await deviceInfo.androidInfo;
        deviceBrand = androidInfo.brand ?? 'your device';
      } catch (e) {
        // Use default
      }
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Find Your Downloaded File',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To find your downloaded file, follow these steps:',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 16),
              _buildInstructionStep(
                '1',
                'Open your File Manager',
                'Look for apps like "Files", "My Files", or "File Manager"',
              ),
              SizedBox(height: 12),
              _buildInstructionStep(
                '2',
                'Navigate to Downloads',
                'Find and tap on the "Downloads" or "Download" folder',
              ),
              SizedBox(height: 12),
              _buildInstructionStep(
                '3',
                'Find your file',
                'Look for the file you just downloaded',
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Common File Manager Apps:',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _getFileManagerAppsForDevice(deviceBrand),
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Got it', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(
      String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getFileManagerAppsForDevice(String brand) {
    final brandLower = brand.toLowerCase();

    if (brandLower.contains('samsung')) {
      return '• My Files (Samsung)\n• Files by Google\n• File Manager';
    } else if (brandLower.contains('xiaomi') || brandLower.contains('mi')) {
      return '• Mi File Manager\n• Files by Google\n• File Manager+';
    } else if (brandLower.contains('huawei')) {
      return '• Files (Huawei)\n• Files by Google\n• File Manager';
    } else if (brandLower.contains('oppo')) {
      return '• File Manager (ColorOS)\n• Files by Google';
    } else if (brandLower.contains('vivo')) {
      return '• File Manager (Vivo)\n• Files by Google';
    } else {
      return '• Files by Google\n• File Manager\n• Documents\n• Total Commander';
    }
  }

// Copy file path to clipboard
  Future<void> _copyFilePathToClipboard(String filePath) async {
    try {
      await Clipboard.setData(ClipboardData(text: filePath));
      _showSnackBar('File path copied to clipboard', isSuccess: true);
    } catch (e) {
      AppLogger.error('Could not copy to clipboard', e);
      _showSnackBar('Could not copy path', isSuccess: false);
    }
  }

// Open file manager (Android)
  Future<void> _openFileManager() async {
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('com.yourapp.file_manager');
        await platform.invokeMethod('openFileManager');
      } catch (e) {
        // Fallback: try to open Downloads folder via URL
        try {
          final Uri uri = Uri.parse(
              'content://com.android.externalstorage.documents/document/primary%3ADownload');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        } catch (e2) {
          _showSnackBar('Could not open file manager', isSuccess: false);
        }
      }
    }
  }

  Future<void> _copyLink(String path) async {
    final generateLinkUsecase = getIt<GenerateLinkUsecase>();
    final fileName = path.split('/').last;
    final folderPath = path.replaceFirst('/$fileName', '');
    final url = await generateLinkUsecase.fileUrl(folderPath, fileName);

    await Clipboard.setData(ClipboardData(text: url));
    _showSnackBar('Link copied to clipboard', isSuccess: true);
  }

  Future<void> _openInBrowser(String path) async {
    // final url = 'https://project.ibartstech.com$path';
    final generateLinkUsecase = getIt<GenerateLinkUsecase>();
    final String url;

    if (path.contains('.')) {
      // It's a file
      final fileName = path.split('/').last;
      final folderPath = path.replaceFirst('/$fileName', '');
      url = await generateLinkUsecase.fileUrl(folderPath, fileName);
    } else {
      // It's a folder
      url = await generateLinkUsecase.folderUrl(path);
    }

    final uri = Uri.parse(url);

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // For mobile platforms, use external application mode
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // For desktop platforms, check if can launch then launch
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        } else {
          throw Exception('Cannot launch URL');
        }
      }
    } catch (e) {
      _showSnackBar('Could not open URL in browser', isSuccess: false);
    }
  }

  void _showSnackBar(String message,
      {bool isSuccess = true, bool showProgress = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (showProgress)
              CircularProgressIndicator(
                year2023: false,
                color: AppColors.primaryLight,
                backgroundColor: AppColors.darkSurface,
              ),
            if (showProgress) const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  MimeType _getMimeType(String? ext) {
    if (ext == null) return MimeType.other;
    const mimeMap = {
      'jpg': MimeType.jpeg,
      'jpeg': MimeType.jpeg,
      'png': MimeType.png,
      'gif': MimeType.gif,
      'pdf': MimeType.pdf,
      'doc': MimeType.other,
      'docx': MimeType.other,
      'xls': MimeType.other,
      'xlsx': MimeType.other,
      'zip': MimeType.zip,
      'mp3': MimeType.mp3,
      'mp4': MimeType.mp4Video,
    };
    return mimeMap[ext.toLowerCase()] ?? MimeType.other;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, String text,
      {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color ?? AppColors.primaryLight),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color ?? Colors.white)),
        ],
      ),
    );
  }

  Future<void> _renameItem(String path, String name, bool isFolder) async {
    final newNameController = TextEditingController(text: name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title: Text('Rename ${isFolder ? 'Folder' : 'File'}',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: newNameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'New name',
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: 'Enter new name',
            hintStyle: const TextStyle(color: Colors.white54),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.primaryLight.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.primaryLight.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
            ),
            filled: true,
            fillColor: AppColors.darkSurface.withOpacity(0.8),
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, newNameController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != name) {
      try {
        // Get the parent path and construct new path
        final parentPath = path.substring(0, path.lastIndexOf('/'));
        final newPath =
            isFolder ? '$parentPath/$result' : '$parentPath/$result';
        if (isFolder) {
          await getIt<RenameFolderUsecase>()(path, newPath);
        } else {
          await getIt<RenameFileUsecase>()(path, newPath);
        }
        _showSnackBar('${isFolder ? 'Folder' : 'File'} renamed successfully',
            isSuccess: true);
        // Reload the current folder
        ref
            .read(folderBrowserViewModelProvider.notifier)
            .load(widget.folderPath);
      } catch (e) {
        _showSnackBar('Failed to rename: $e', isSuccess: false);
      }
    }
  }

  Widget _buildFolderTile(FTPFolder folder) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(Icons.folder, color: Colors.amber[300]),
        title: Text(folder.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text('Folder', style: const TextStyle(color: Colors.white70)),
        onTap: () {
          // Clear search query when navigating to a new folder
          ref.read(folderBrowserViewModelProvider.notifier).setSearchQuery('');
          context.push(RouteNames.folderBrowserPath(folder.fullPath));
        },
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppColors.primaryLight),
          color: AppColors.darkSurface,
          onSelected: (value) async {
            switch (value) {
              case 'open':
                _openInBrowser(folder.fullPath);
                break;
              case 'rename':
                _renameItem(folder.fullPath, folder.name, true);
                break;
              case 'delete':
                _deleteItem(folder.fullPath, folder.name, true);
                break;
            }
          },
          itemBuilder: (context) => [
            _buildMenuItem('open', Icons.open_in_browser, 'Open in browser'),
            _buildMenuItem('rename', Icons.edit, 'Rename'),
            _buildMenuItem('delete', Icons.delete, 'Delete',
                color: Colors.red[300]),
          ],
        ),
      ),
    );
  }

  Widget _buildFileTile(FTPFile file) {
    final isDownloading = _isDownloadingMap[file.fullPath] ?? false;
    final downloadProgress = _downloadProgressMap[file.fullPath] ?? 0.0;
    final downloadingFileName = _downloadingFileNameMap[file.fullPath] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(_getFileIcon(file.extension),
                color: _getFileIconColor(file.extension)),
            title: Text(file.name, style: const TextStyle(color: Colors.white)),
            subtitle: isDownloading
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_formatSize(file.size)}',
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: downloadProgress,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary),
                              minHeight: 4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(downloadProgress * 100).toInt()}%',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _getProgressText(file.fullPath),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  )
                : Text('${_formatSize(file.size)}',
                    style: const TextStyle(color: Colors.white70)),
            trailing: isDownloading
                ? IconButton(
                    icon: Icon(Icons.stop, color: Colors.red),
                    onPressed: () {
                      final cancelFunc = _cancelDownloadMap[file.fullPath];
                      if (cancelFunc != null) {
                        cancelFunc();
                        setState(() {
                          _isDownloadingMap[file.fullPath] = false;
                          _downloadProgressMap.remove(file.fullPath);
                          _cancelDownloadMap.remove(file.fullPath);
                        });
                      }
                    },
                  )
                : PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: AppColors.primaryLight),
                    color: AppColors.darkSurface,
                    onSelected: (value) async {
                      switch (value) {
                        case 'download':
                          _downloadFile(file);
                          break;
                        case 'open':
                          _openInBrowser(file.fullPath);
                          break;
                        case 'copy':
                          _copyLink(file.fullPath);
                          break;
                        case 'rename':
                          _renameItem(file.fullPath, file.name, false);
                          break;
                        case 'delete':
                          _deleteItem(file.fullPath, file.name, false);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      _buildMenuItem('download', Icons.download, 'Download'),
                      _buildMenuItem(
                          'open', Icons.open_in_browser, 'Open in browser'),
                      _buildMenuItem('copy', Icons.link, 'Copy link'),
                      _buildMenuItem('rename', Icons.edit, 'Rename'),
                      _buildMenuItem('delete', Icons.delete, 'Delete',
                          color: Colors.red[300]),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(folderBrowserViewModelProvider);
    final viewModel = ref.read(folderBrowserViewModelProvider.notifier);

    return WillPopScope(
      onWillPop: () async {
        // Calculate the parent path
        String? parentPath;
        if (widget.folderPath != '/') {
          List<String> pathParts = widget.folderPath.split('/');
          if (pathParts.length > 1) {
            pathParts.removeLast(); // Remove current folder
            if (pathParts.length == 1 && pathParts[0].isEmpty) {
              parentPath = '/'; // Go back to root folder
            } else {
              parentPath = pathParts.join('/');
              if (parentPath.isEmpty) parentPath = '/';
            }
          } else {
            // If we're at a direct child of root (e.g., /folder1/), go to file manager screen
            parentPath = null; // This will cause navigation to file manager
          }
        } else {
          // If we're already at the root folder, go to file manager screen
          parentPath = null;
        }
        
        // Navigate to parent folder or back to file manager
        if (parentPath != null && parentPath != widget.folderPath) {
          context.go(RouteNames.folderBrowserPath(parentPath));
          return false; // Prevent default pop behavior
        } else if (parentPath == null) {
          // Navigate back to the file manager screen (root screen with settings/logout)
          context.go(RouteNames.fileManager);
          return false; // Prevent default pop behavior
        }
        
        return true; // Allow normal pop if at root
      },
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        appBar: AppBar(
          title: Text(widget.folderPath,
              style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.darkSurface,
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: AppColors.primaryLight),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.primaryLight),
            onPressed: () {
              // Calculate the parent path
              String? parentPath;
              if (widget.folderPath != '/') {
                List<String> pathParts = widget.folderPath.split('/');
                if (pathParts.length > 1) {
                  pathParts.removeLast(); // Remove current folder
                  if (pathParts.length == 1 && pathParts[0].isEmpty) {
                    parentPath = '/'; // Go back to root folder
                  } else {
                    parentPath = pathParts.join('/');
                    if (parentPath.isEmpty) parentPath = '/';
                  }
                } else {
                  // If we're at a direct child of root (e.g., /folder1/), go to file manager screen
                  parentPath = null; // This will cause navigation to file manager
                }
              } else {
                // If we're already at the root folder, go to file manager screen
                parentPath = null;
              }
              
              // Navigate to parent folder or back to file manager
              if (parentPath != null) {
                context.go(RouteNames.folderBrowserPath(parentPath));
              } else {
                context.go(RouteNames.fileManager);
              }
            },
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.5,
              colors: [
                Color(0xFF1A0033),
                AppColors.darkBackground,
              ],
              stops: [0.1, 0.9],
            ),
          ),
          child: Column(
            children: [
              // Search and sort controls
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Search field
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primaryLight.withOpacity(0.3)),
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search files and folders...',
                            hintStyle: TextStyle(color: Colors.white54),
                            prefixIcon:
                                Icon(Icons.search, color: AppColors.primaryLight),
                            suffixIcon: state.searchQuery != null &&
                                    state.searchQuery!.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear,
                                        color: Colors.grey[400]),
                                    onPressed: () => viewModel.setSearchQuery(''),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          style: TextStyle(color: Colors.white),
                          onChanged: (value) => viewModel.setSearchQuery(value),
                          autofocus: false, // Disable auto-focus
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Sort button
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primaryLight.withOpacity(0.3)),
                      ),
                      child: PopupMenuButton<FolderSortOption>(
                        color: AppColors.darkSurface,
                        icon: Icon(Icons.sort, color: AppColors.primaryLight),
                        onSelected: (option) => viewModel.setSortOption(option),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: FolderSortOption.name,
                            child: Row(
                              children: [
                                Icon(Icons.text_fields,
                                    color: AppColors.primaryLight),
                                const SizedBox(width: 8),
                                Text('Sort by Name',
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: FolderSortOption.nameReverse,
                            child: Row(
                              children: [
                                Icon(Icons.text_fields,
                                    color: AppColors.primaryLight),
                                const SizedBox(width: 8),
                                Text('Sort by Name (Z-A)',
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Main content
              Expanded(
                child: state.loading
                    ? Center(
                        child: CircularProgressIndicator(
                        year2023: false,
                        color: AppColors.primaryLight,
                        backgroundColor: AppColors.darkSurface,
                      ))
                    : RefreshIndicator(
                        backgroundColor: AppColors.darkSurface,
                        color: AppColors.primaryLight,
                        onRefresh: () => ref
                            .read(folderBrowserViewModelProvider.notifier)
                            .load(widget.folderPath),
                        child: ListView(
                          children: [
                            if (state.error != null)
                              _buildErrorCard(state.error!),

                            // Current path
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              child: Text(
                                'Path: ${widget.folderPath}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ),

                            // Results count
                            if (state.searchQuery != null &&
                                state.searchQuery!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                child: Text(
                                  '${state.folders.length + state.files.length} result(s) found for "${state.searchQuery}"',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 14),
                                ),
                              ),

                            if (state.folders.isNotEmpty)
                              _buildSectionHeader('Folders'),
                            ...state.folders.map(_buildFolderTile),
                            if (state.files.isNotEmpty)
                              _buildSectionHeader('Files'),
                            ...state.files.map(_buildFileTile),
                            if (state.folders.isEmpty &&
                                state.files.isEmpty &&
                                (state.searchQuery == null ||
                                    state.searchQuery!.isEmpty))
                              _buildEmptyState(),
                            if (state.folders.isEmpty &&
                                state.files.isEmpty &&
                                state.searchQuery != null &&
                                state.searchQuery!.isNotEmpty)
                              _buildNoSearchResults(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () =>
              context.go(RouteNames.uploadPath(folderPath: widget.folderPath)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.upload, color: Colors.white),
        ),
      ),
    );
 }

  Widget _buildErrorCard(String error) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red[300]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(color: Colors.red[300]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(title,
          style: TextStyle(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.bold,
              fontSize: 16)),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Folder is empty',
                style: TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Upload files or create subfolders',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No results found',
                style: TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Try a different search term',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String? ext) {
    if (ext == null) return Icons.insert_drive_file;
    const iconMap = {
      'jpg': Icons.image,
      'jpeg': Icons.image,
      'png': Icons.image,
      'gif': Icons.image,
      'mp4': Icons.video_file,
      'avi': Icons.video_file,
      'mov': Icons.video_file,
      'mp3': Icons.audio_file,
      'wav': Icons.audio_file,
      'flac': Icons.audio_file,
      'pdf': Icons.picture_as_pdf,
      'doc': Icons.description,
      'docx': Icons.description,
      'xls': Icons.table_chart,
      'xlsx': Icons.table_chart,
      'zip': Icons.archive,
      'rar': Icons.archive,
      '7z': Icons.archive,
      'txt': Icons.text_snippet,
    };
    return iconMap[ext.toLowerCase()] ?? Icons.insert_drive_file;
  }

  Color _getFileIconColor(String? ext) {
    if (ext == null) return Colors.grey[400]!;
    const colorMap = {
      'jpg': Colors.green,
      'jpeg': Colors.green,
      'png': Colors.green,
      'gif': Colors.green,
      'mp4': Colors.red,
      'avi': Colors.red,
      'mov': Colors.red,
      'mp3': Colors.purple,
      'wav': Colors.purple,
      'flac': Colors.purple,
      'pdf': Colors.red,
      'doc': Colors.blue,
      'docx': Colors.blue,
      'xls': Colors.green,
      'xlsx': Colors.green,
      'zip': Colors.orange,
      'rar': Colors.orange,
      '7z': Colors.orange,
      'txt': Colors.grey,
    };
    return colorMap[ext.toLowerCase()]?[300] ?? Colors.grey[400]!;
  }
}
