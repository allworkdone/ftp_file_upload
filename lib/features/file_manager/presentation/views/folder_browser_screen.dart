import 'dart:async';
import 'dart:io' show Directory, File, Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_upload/core/utils/app_logger.dart';
import 'package:file_upload/core/utils/file_utils.dart';
import 'package:file_upload/core/utils/permission_utils.dart';
import 'package:file_upload/core/utils/cancel_token.dart';
import 'package:file_upload/features/authentication/domain/entities/ftp_credentials.dart';
import 'package:file_upload/features/authentication/presentation/viewmodels/auth_viewmodel.dart';
import 'package:file_upload/features/file_manager/data/datasources/ftp_datasource.dart';
import 'package:file_upload/features/file_manager/domain/usecases/generate_link_usecase.dart';
import 'package:file_upload/features/file_manager/domain/usecases/rename_file_usecase.dart';
import 'package:file_upload/features/file_manager/domain/usecases/rename_folder_usecase.dart';
import 'package:file_upload/features/file_manager/domain/usecases/search_files_usecase.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../file_manager/domain/entities/ftp_file.dart';
import '../../../file_manager/domain/entities/ftp_folder.dart';
import '../../../file_manager/domain/usecases/delete_file_usecase.dart';
import '../../../file_manager/domain/usecases/delete_folder_usecase.dart';
import '../../../file_manager/domain/usecases/get_files_usecase.dart';
import '../../../file_manager/domain/usecases/get_folders_usecase.dart';

class FolderBrowserScreen extends ConsumerStatefulWidget {
  final String folderPath;
  const FolderBrowserScreen({super.key, required this.folderPath});

  @override
  ConsumerState<FolderBrowserScreen> createState() =>
      _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends ConsumerState<FolderBrowserScreen> {
  bool _loading = true;
  bool _searching = false;
  List<FTPFolder> _folders = const [];
  List<FTPFile> _files = const [];
  List<FTPFolder> _filteredFolders = const [];
  List<FTPFile> _filteredFiles = const [];
  List<SearchResult> _searchResults = const [];
  String _searchQuery = '';
  String? _error;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  String _downloadingFileName = '';
  CancelToken? _searchCancelToken;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        getIt<GetFoldersUsecase>()(widget.folderPath),
        getIt<GetFilesUsecase>()(widget.folderPath),
      ]);
      if (mounted) {
        setState(() {
          _folders = results[0] as List<FTPFolder>;
          _files = results[1] as List<FTPFile>;
          _filteredFolders = _folders;
          _filteredFiles = _files;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
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
      _load();
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

  void _search(String query) {
    // Cancel any existing debounce timer
    _searchDebounceTimer?.cancel();
    
    setState(() {
      _searchQuery = query;
    });

    // If query is empty, clear search results immediately
    if (query.isEmpty) {
      _searchDebounceTimer = Timer(Duration.zero, () {
        if (mounted) {
          setState(() {
            _filteredFolders = _folders;
            _filteredFiles = _files;
            _searchResults = const [];
            _searching = false;
          });
        }
      });
      return;
    }

    // Debounce the search to avoid too many requests
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) async {
    // Cancel any ongoing search
    _searchCancelToken?.cancel();
    _searchCancelToken = CancelToken();

    // For short queries, search only in current folder
    if (query.length < 3) {
      setState(() {
        _filteredFolders = _folders.where((folder) => 
          folder.name.toLowerCase().contains(query.toLowerCase())
        ).toList();
        
        _filteredFiles = _files.where((file) => 
          file.name.toLowerCase().contains(query.toLowerCase())
        ).toList();
        
        _searchResults = const [];
        _searching = false;
      });
      return;
    }

    // For longer queries, perform recursive search
    setState(() {
      _searching = true;
      _filteredFolders = const [];
      _filteredFiles = const [];
    });

    try {
      final results = await getIt<SearchFilesUsecase>()(query, widget.folderPath);
      if (mounted && !_searchCancelToken!.isCancelled) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted && !_searchCancelToken!.isCancelled) {
        setState(() {
          _searchResults = const [];
          _searching = false;
          _error = 'Search failed: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _searchCancelToken?.cancel();
    super.dispose();
  }

  Future<void> _renameItem(String oldPath, String name, bool isFolder) async {
    final newName = await _showRenameDialog(name);
    if (newName == null || newName.trim().isEmpty || newName == name) return;

    try {
      final parentPath = oldPath.substring(0, oldPath.lastIndexOf('/'));
      final newPath = parentPath.isEmpty ? '/$newName' : '$parentPath/$newName';
      
      if (isFolder) {
        await getIt<RenameFolderUsecase>()(oldPath, newPath);
      } else {
        await getIt<RenameFileUsecase>()(oldPath, newPath);
      }
      
      _showSnackBar('$name renamed to $newName successfully', isSuccess: true);
      _load();
    } catch (e) {
      _showSnackBar('Failed to rename: $e', isSuccess: false);
    }
  }

  Future<String?> _showRenameDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);
    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title: const Text('Rename', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'New name',
            labelStyle: const TextStyle(color: Colors.white70),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryLight.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryLight.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
            ),
            filled: true,
            fillColor: AppColors.darkSurface.withOpacity(0.8),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rename'),
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
      // Reset progress
      setState(() {
        _downloadProgress = 0.0;
        _isDownloading = true;
        _downloadingFileName = file.name;
      });

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
              setState(() => _isDownloading = false);
              return;
            }
          }

          final granted = await permissionUtils.requestStoragePermission();

          if (!granted) {
            setState(() => _isDownloading = false);
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

      // Update progress to 10%
      setState(() => _downloadProgress = 0.1);
      _showSnackBar('Starting download of "${file.name}"...',
          showProgress: false);

      // Get credentials from auth
      final auth = ref.read(authViewModelProvider);
      if (auth.credentials == null) {
        setState(() => _isDownloading = false);
        _showSnackBar('No FTP credentials available', isSuccess: false);
        return;
      }

      // Update progress to 20%
      setState(() => _downloadProgress = 0.2);

      // Use FTP datasource with progress callback
      final ftpDatasource = getIt<FTPDatasource>();

      // Get temporary directory for download
      final tempDir = Directory.systemTemp;
      final tempPath = tempDir.path;

      // Update progress to 30%
      setState(() => _downloadProgress = 0.3);

      // Download file via FTP to temp location with progress tracking
      final localFilePath = await _downloadFileWithProgress(
        ftpDatasource,
        auth.credentials!,
        file.fullPath,
        tempPath,
        file.size ?? 0,
      );

      // Progress is now at 80% from download
      setState(() => _downloadProgress = 0.85);

      // Read the downloaded file
      final downloadedFile = File(localFilePath);
      final bytes = await downloadedFile.readAsBytes();

      // Update progress to 90%
      setState(() => _downloadProgress = 0.9);

      // Save to Downloads folder using the improved method
      final savedFilePath = await FileUtils.saveToDownloads(file.name, bytes);

      // Update progress to 95%
      setState(() => _downloadProgress = 0.95);

      if (savedFilePath != null) {
        // Clean up temp file
        try {
          await downloadedFile.delete();
        } catch (e) {
          AppLogger.error('Could not clean up temp file', e);
        }

        // Complete progress
        setState(() => _downloadProgress = 1.0);

        // Small delay to show 100%
        await Future.delayed(Duration(milliseconds: 500));

        setState(() => _isDownloading = false);

        _showSnackBar('Download completed successfully!', isSuccess: true);

        // Show download complete dialog
        _showDownloadCompleteDialog(savedFilePath);
      } else {
        throw Exception('Failed to save file to Downloads folder');
      }
    } catch (e) {
      setState(() => _isDownloading = false);
      AppLogger.error('Download failed', e);
      _showSnackBar('Download failed: ${e.toString()}', isSuccess: false);
    }
  }

// Modified FTP download with progress tracking
  Future<String> _downloadFileWithProgress(
    FTPDatasource ftpDatasource,
    FTPCredentials credentials,
    String remotePath,
    String localDir,
    int fileSize,
  ) async {
    // This is a wrapper that simulates progress for FTP download
    // You'll need to modify your FTPDatasource to support progress callbacks

    final completer = Completer<String>();

    // Start the actual download
    ftpDatasource.downloadFile(credentials, remotePath, localDir).then((path) {
      setState(() => _downloadProgress = 0.8);
      completer.complete(path);
    }).catchError((error) {
      completer.completeError(error);
    });

    // Simulate progress updates during download (you can replace this with actual FTP progress)
    Timer.periodic(Duration(milliseconds: 200), (timer) {
      if (completer.isCompleted) {
        timer.cancel();
        return;
      }

      if (_downloadProgress < 0.75) {
        setState(() => _downloadProgress += 0.05);
      }
    });

    return completer.future;
  }

// Widget to show download progress
  Widget _buildDownloadProgress() {
    if (!_isDownloading) return SizedBox.shrink();

    // Find the file being downloaded to get its details
    FTPFile? downloadingFile;
    for (final file in _files) {
      if (file.name == _downloadingFileName) {
        downloadingFile = file;
        break;
      }
    }

    final fileSize = downloadingFile?.size ?? 0;
    final downloadedBytes = (fileSize * _downloadProgress).toInt();

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // File info row
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  FileUtils.getFileIcon(downloadingFile?.extension),
                  color: FileUtils.getFileIconColor(downloadingFile?.extension),
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Downloading',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _downloadingFileName,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              // Cancel button
              IconButton(
                onPressed: () {
                  setState(() {
                    _isDownloading = false;
                    _downloadProgress = 0.0;
                  });
                  _showSnackBar('Download cancelled', isSuccess: false);
                },
                icon: Icon(Icons.close, color: Colors.white70, size: 20),
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.all(4),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Progress section
          Column(
            children: [
              // Progress stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Percentage
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(_downloadProgress * 100).toInt()}%',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  // File size info
                  if (fileSize > 0) ...[
                    Text(
                      '${FileUtils.formatSize(downloadedBytes)} / ${FileUtils.formatSize(fileSize)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else ...[
                    Text(
                      _getProgressText(),
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),

              SizedBox(height: 8),

              // Progress bar
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white12,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: Colors.transparent,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 8,
                  ),
                ),
              ),

              SizedBox(height: 8),

              // Status text
              Text(
                _getProgressText(),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),

              // Speed and ETA (if available)
              if (_downloadProgress > 0.1 && _downloadProgress < 1.0) ...[
                SizedBox(height: 4),
                Text(
                  _getDownloadStats(fileSize),
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _getProgressText() {
    if (_downloadProgress < 0.05) return 'Initializing download...';
    if (_downloadProgress < 0.1) return 'Requesting permissions...';
    if (_downloadProgress < 0.2) return 'Connecting to server...';
    if (_downloadProgress < 0.3) return 'Authenticating...';
    if (_downloadProgress < 0.8) return 'Downloading file...';
    if (_downloadProgress < 0.9) return 'Saving to device...';
    if (_downloadProgress < 0.95) return 'Finalizing...';
    if (_downloadProgress < 1.0) return 'Almost done...';
    return 'Download complete!';
  }

// Calculate and display download stats
  String _getDownloadStats(int fileSize) {
    if (fileSize <= 0 || _downloadProgress <= 0.1) return '';

    // Estimate remaining time (very rough calculation)
    final elapsedTime =
        Duration(seconds: 5); // Placeholder - you'd track actual time
    final remainingProgress = 1.0 - _downloadProgress;
    final estimatedTotalTime = elapsedTime.inSeconds / _downloadProgress;
    final remainingTime = (estimatedTotalTime * remainingProgress).toInt();

    if (remainingTime > 60) {
      final minutes = (remainingTime / 60).ceil();
      return 'About ${minutes}m remaining';
    } else if (remainingTime > 0) {
      return 'About ${remainingTime}s remaining';
    } else {
      return 'Finishing up...';
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

  String _formatSize(int bytes) {
    if (bytes == 0) return '0 B';
    if (bytes < 1024) return '$bytes B';

    final kb = bytes / 1024;
    if (kb < 1024) {
      return kb < 10 ? '${kb.toStringAsFixed(1)} KB' : '${kb.toInt()} KB';
    }

    final mb = kb / 1024;
    if (mb < 1024) {
      return mb < 10 ? '${mb.toStringAsFixed(1)} MB' : '${mb.toInt()} MB';
    }

    final gb = mb / 1024;
    return gb < 10 ? '${gb.toStringAsFixed(1)} GB' : '${gb.toInt()} GB';
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
        subtitle: Text(
            '${folder.totalFiles} files • ${folder.totalSubFolders} folders',
            style: const TextStyle(color: Colors.white70)),
        onTap: () =>
            context.push(RouteNames.folderBrowserPath(folder.fullPath)),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(FileUtils.getFileIcon(file.extension),
            color: FileUtils.getFileIconColor(file.extension)),
        title: Text(file.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text('${FileUtils.formatSize(file.size)}',
            style: const TextStyle(color: Colors.white70)),
        trailing: PopupMenuButton<String>(
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
            _buildMenuItem('open', Icons.open_in_browser, 'Open in browser'),
            _buildMenuItem('copy', Icons.link, 'Copy link'),
            _buildMenuItem('rename', Icons.edit, 'Rename'),
            _buildMenuItem('delete', Icons.delete, 'Delete',
                color: Colors.red[300]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text(widget.folderPath,
            style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.darkSurface,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: AppColors.primaryLight),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: _search,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search files and folders...',
                      hintStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: AppColors.darkSurface.withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primaryLight, width: 1),
                      ),
                    ),
                  ),
                ),
                if (_searching)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: IconButton(
                      icon: Icon(Icons.cancel, color: Colors.white70),
                      onPressed: () {
                        _searchCancelToken?.cancel();
                        setState(() {
                          _searching = false;
                          _searchResults = const [];
                          _searchQuery = '';
                        });
                        _showSnackBar('Search cancelled', isSuccess: true);
                      },
                    ),
                  ),
              ],
            ),
          ),
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
        child: Stack(
          children: [
            // Main content
            _loading
                ? Center(
                    child: CircularProgressIndicator(
                    color: AppColors.primaryLight,
                    backgroundColor: AppColors.darkSurface,
                  ))
                : RefreshIndicator(
                    backgroundColor: AppColors.darkSurface,
                    color: AppColors.primaryLight,
                    onRefresh: _load,
                    child: ListView(
                      children: [
                        if (_error != null) _buildErrorCard(),

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

                        // Show search results when searching
                        if (_searchQuery.isNotEmpty && _searchResults.isNotEmpty) ...[
                          _buildSectionHeader('Search Results (${_searchResults.length})'),
                          ..._searchResults.map(_buildSearchResultTile),
                        ] else if (_searching) ...[
                          _buildSectionHeader('Searching...'),
                          _buildEmptyState(),
                        ] else ...[
                          if (_filteredFolders.isNotEmpty) _buildSectionHeader('Folders'),
                          ..._filteredFolders.map(_buildFolderTile),
                          if (_filteredFiles.isNotEmpty) _buildSectionHeader('Files'),
                          ..._filteredFiles.map(_buildFileTile),
                        ],
                        
                        if (_filteredFolders.isEmpty && 
                            _filteredFiles.isEmpty && 
                            _searchResults.isEmpty &&
                            !_searching)
                          _buildEmptyState(),

                        // Add spacing at bottom for download progress
                        if (_isDownloading) SizedBox(height: 120),
                      ],
                    ),
                  ),

            // Download progress overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildDownloadProgress(),
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
    );
  }

  Widget _buildErrorCard() {
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
                _error!,
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

  Widget _buildSearchResultTile(SearchResult result) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(
          result.isFile ? FileUtils.getFileIcon(result.extension) : Icons.folder,
          color: result.isFile 
            ? FileUtils.getFileIconColor(result.extension) 
            : Colors.amber[300],
        ),
        title: Text(result.name, style: const TextStyle(color: Colors.white)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.isFile) 
              Text('${FileUtils.formatSize(result.size ?? 0)}',
                  style: const TextStyle(color: Colors.white70)),
            Text(result.parentPath,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        onTap: () {
          if (result.isFile) {
            // For files, we might want to download or open them
            // For now, let's just show a snackbar
            _showSnackBar('File found in ${result.parentPath}', isSuccess: true);
          } else {
            // For folders, navigate to the folder
            context.push(RouteNames.folderBrowserPath(result.path));
          }
        },
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppColors.primaryLight),
          color: AppColors.darkSurface,
          onSelected: (value) async {
            switch (value) {
              case 'navigate':
                if (result.isFile) {
                  // For files, navigate to parent folder
                  context.push(RouteNames.folderBrowserPath(result.parentPath));
                } else {
                  // For folders, navigate to the folder
                  context.push(RouteNames.folderBrowserPath(result.path));
                }
                break;
              case 'download':
                if (result.isFile) {
                  // Create a temporary FTPFile for download
                  final file = FTPFile(
                    name: result.name,
                    path: result.parentPath,
                    type: FTPFileType.file,
                    size: result.size ?? 0,
                    extension: result.extension,
                  );
                  _downloadFile(file);
                }
                break;
            }
          },
          itemBuilder: (context) => [
            _buildMenuItem('navigate', Icons.open_in_browser, 'Go to location'),
            if (result.isFile) _buildMenuItem('download', Icons.download, 'Download'),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      if (_searching) {
        return Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(
                  color: AppColors.primaryLight,
                ),
                const SizedBox(height: 16),
                const Text('Searching...',
                    style: TextStyle(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 8),
                Text('Looking for "$_searchQuery" in all folders',
                    style: const TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        );
      }
      
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('No matching items found',
                  style: TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 8),
              Text('No files or folders match your search for "$_searchQuery"',
                  style: const TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }
    
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
}
