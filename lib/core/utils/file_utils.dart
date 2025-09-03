import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'app_logger.dart';

class FileUtils {
  /// Get application documents directory
  Future<Directory> getAppDocumentsDirectory() async {
    if (Platform.isMacOS) {
      // On macOS, use application support directory for better sandboxing support
      return await getApplicationSupportDirectory();
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  /// Get temporary directory
  Future<Directory> getTempDirectory() async {
    return await getTemporaryDirectory();
  }

  /// Get file size in bytes
  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      AppLogger.error('Error getting file size: $filePath', e);
      return 0;
    }
  }

  /// Get file extension
  String getFileExtension(String filePath) {
    return filePath.split('.').last.toLowerCase();
  }

  /// Get file name without extension
  String getFileNameWithoutExtension(String filePath) {
    final fileName = filePath.split('/').last;
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex == -1) return fileName;
    return fileName.substring(0, lastDotIndex);
  }

  /// Get file name with extension
  String getFileName(String filePath) {
    return filePath.split('/').last;
  }

  /// Format file size to human readable format
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Check if file exists
  Future<bool> fileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      AppLogger.error('Error checking file existence: $filePath', e);
      return false;
    }
  }

  /// Read file as bytes
  Future<Uint8List?> readFileAsBytes(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      AppLogger.error('Error reading file as bytes: $filePath', e);
      return null;
    }
  }

  /// Pick single file using file picker with enhanced macOS support
  Future<PlatformFile?> pickSingleFile({
    List<String>? allowedExtensions,
    FileType type = FileType.any,
  }) async {
    try {
      AppLogger.info('Starting file picker...');
      AppLogger.info('Platform: ${Platform.operatingSystem}');

      // Configure picker settings with macOS optimizations
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
        withData: false, // Don't load into memory for large files
        withReadStream: false,
        lockParentWindow:
            Platform.isMacOS, // Important for macOS modal behavior
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        AppLogger.info('File selected: ${file.name}');
        AppLogger.info('Path: ${file.path}');
        AppLogger.info('Size: ${file.size} bytes');

        // Verify file accessibility on macOS
        if (Platform.isMacOS) {
          final fileEntity = File(file.path!);
          final exists = await fileEntity.exists();
          final readable = await _isFileReadable(fileEntity);

          AppLogger.info('File exists: $exists');
          AppLogger.info('File readable: $readable');

          if (!exists) {
            throw Exception('Selected file does not exist');
          }

          if (!readable) {
            throw Exception(
                'Selected file is not readable. Please check permissions.');
          }
        }

        return file;
      }

      AppLogger.info('No file selected');
      return null;
    } catch (e) {
      AppLogger.error('Error picking file', e);

      if (Platform.isMacOS && e.toString().contains('not permitted')) {
        throw Exception(
            'File access not permitted. Please check macOS privacy settings and app entitlements.');
      }

      return null;
    }
  }

  /// Pick multiple files with enhanced macOS support
  Future<List<PlatformFile>?> pickMultipleFiles({
    List<String>? allowedExtensions,
    FileType type = FileType.any,
  }) async {
    try {
      AppLogger.info('Starting multiple file picker...');

      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
        withData: false,
        withReadStream: false,
        lockParentWindow: Platform.isMacOS,
      );

      if (result != null) {
        final validFiles = <PlatformFile>[];

        for (final file in result.files) {
          if (file.path != null) {
            AppLogger.info('Processing file: ${file.name}');

            if (Platform.isMacOS) {
              final fileEntity = File(file.path!);
              final exists = await fileEntity.exists();
              final readable = await _isFileReadable(fileEntity);

              if (exists && readable) {
                validFiles.add(file);
              } else {
                AppLogger.warning('Skipping inaccessible file: ${file.name}');
              }
            } else {
              validFiles.add(file);
            }
          }
        }

        AppLogger.info('${validFiles.length} valid files selected');
        return validFiles;
      }

      return null;
    } catch (e) {
      AppLogger.error('Error picking multiple files', e);
      return null;
    }
  }

  /// Check if a file is readable
  Future<bool> _isFileReadable(File file) async {
    try {
      final stat = await file.stat();
      return stat.type == FileSystemEntityType.file;
    } catch (e) {
      AppLogger.error('File readability check failed', e);
      return false;
    }
  }

  /// Validate file path and permissions
  Future<bool> validateFilePath(String filePath) async {
    try {
      final file = File(filePath);

      // Check if file exists
      if (!await file.exists()) {
        AppLogger.warning('File does not exist: $filePath');
        return false;
      }

      // Check if file is readable
      if (!await _isFileReadable(file)) {
        AppLogger.warning('File is not readable: $filePath');
        return false;
      }

      // Additional macOS-specific checks
      if (Platform.isMacOS) {
        try {
          // Try to read a small portion to verify access
          final stream = file.openRead(0, 1);
          await stream.first;
          AppLogger.info('File validation successful: $filePath');
          return true;
        } catch (e) {
          AppLogger.error('File read test failed', e);
          return false;
        }
      }

      return true;
    } catch (e) {
      AppLogger.error('File validation error', e);
      return false;
    }
  }

  /// Validate file name for FTP upload
  bool isValidFileName(String fileName) {
    // Check for invalid characters
    const invalidChars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
    for (final char in invalidChars) {
      if (fileName.contains(char)) return false;
    }

    // Check length
    if (fileName.isEmpty || fileName.length > 255) return false;

    // Check for reserved names (Windows)
    const reservedNames = [
      'CON',
      'PRN',
      'AUX',
      'NUL',
      'COM1',
      'COM2',
      'COM3',
      'COM4',
      'COM5',
      'COM6',
      'COM7',
      'COM8',
      'COM9',
      'LPT1',
      'LPT2',
      'LPT3',
      'LPT4',
      'LPT5',
      'LPT6',
      'LPT7',
      'LPT8',
      'LPT9'
    ];

    final nameWithoutExtension = getFileNameWithoutExtension(fileName);
    return !reservedNames.contains(nameWithoutExtension.toUpperCase());
  }
}
