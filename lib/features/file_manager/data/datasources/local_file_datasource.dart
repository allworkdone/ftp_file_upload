import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../../core/utils/file_utils.dart';

abstract class LocalFileDatasource {
  Future<PlatformFile?> pickSingleFile();
}

class LocalFileDatasourceImpl implements LocalFileDatasource {
  final FileUtils _fileUtils;
  LocalFileDatasourceImpl(this._fileUtils);

  @override
  Future<PlatformFile?> pickSingleFile() async {
    try {
      print(
          '[LocalFileDatasource] Starting file picker on ${Platform.operatingSystem}...');

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: Platform
            .isMacOS, // Load data into memory on macOS for better compatibility
        withReadStream: false,
        lockParentWindow: Platform.isMacOS,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        print('[LocalFileDatasource] File picked: ${file.name}');
        print('[LocalFileDatasource] Path: ${file.path}');
        print('[LocalFileDatasource] Size: ${file.size}');
        print('[LocalFileDatasource] Has bytes: ${file.bytes != null}');

        // Basic validation - only reject if it's clearly a directory and not a valid file
        if (file.path != null) {
          final fileEntity = File(file.path!);

          // Try to access as a file first
          try {
            final exists = await fileEntity.exists();
            if (exists) {
              // It's a regular file, proceed normally
              final actualSize =
                  file.size > 0 ? file.size : await fileEntity.length();
              return PlatformFile(
                name: file.name,
                size: actualSize,
                path: file.path,
                bytes: file.bytes,
              );
            }
          } catch (e) {
            print('[LocalFileDatasource] Could not access as regular file: $e');

            // Check if it might be a directory (bundle) that was selected
            final dirEntity = Directory(file.path!);
            final dirExists = await dirEntity.exists();
            if (dirExists) {
              throw Exception(
                  'Selected item "${file.name}" appears to be a directory/bundle. Please use the bundle selection feature in the upload widget.');
            }
          }
        }

        // On macOS, if we have bytes but no accessible path, that's normal due to sandboxing
        if (Platform.isMacOS && file.bytes != null) {
          print(
              '[LocalFileDatasource] Using bytes data for macOS compatibility');
          return PlatformFile(
            name: file.name,
            size: file.bytes!.length,
            path: null, // Don't rely on path for macOS
            bytes: file.bytes,
          );
        }

        // If we have bytes but no valid path, use the bytes
        if (file.bytes != null) {
          return PlatformFile(
            name: file.name,
            size: file.bytes!.length,
            path: file.path,
            bytes: file.bytes,
          );
        }

        // If we reach here, we have no way to access the file
        throw Exception(
            'Selected file is not accessible and no data is available');
      }

      print('[LocalFileDatasource] No file selected');
      return null;
    } catch (e) {
      print('[LocalFileDatasource] Error picking file: $e');

      if (Platform.isMacOS && e.toString().contains('not permitted')) {
        throw Exception(
            'File access not permitted. Please check macOS privacy settings and app entitlements.');
      }

      // Re-throw with more context if it's our custom validation error
      if (e.toString().contains('appears to be a directory/bundle')) {
        rethrow;
      }

      throw Exception('Failed to pick file: ${e.toString()}');
    }
  }
}
