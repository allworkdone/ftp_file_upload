import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'app_logger.dart';

class FileUtils {
  /// Get application documents directory
  Future<Directory> getAppDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
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
  
  /// Pick single file using file picker
  Future<PlatformFile?> pickSingleFile({
    List<String>? allowedExtensions,
    FileType type = FileType.any,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        return result.files.first;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error picking file', e);
      return null;
    }
  }
  
  /// Pick multiple files
  Future<List<PlatformFile>?> pickMultipleFiles({
    List<String>? allowedExtensions,
    FileType type = FileType.any,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
      );
      
      return result?.files;
    } catch (e) {
      AppLogger.error('Error picking multiple files', e);
      return null;
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
      'CON', 'PRN', 'AUX', 'NUL',
      'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
      'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'
    ];
    
    final nameWithoutExtension = getFileNameWithoutExtension(fileName);
    return !reservedNames.contains(nameWithoutExtension.toUpperCase());
  }
}