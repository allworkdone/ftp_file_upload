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

        // For other platforms or when we have an accessible path
        if (file.path != null) {
          // Verify file accessibility
          final fileEntity = File(file.path!);
          final exists = await fileEntity.exists();
          print('[LocalFileDatasource] File exists: $exists');

          if (exists) {
            // Get actual file size if not provided
            final actualSize =
                file.size > 0 ? file.size : await fileEntity.length();
            return PlatformFile(
              name: file.name,
              size: actualSize,
              path: file.path,
              bytes: file.bytes,
            );
          } else {
            print(
                '[LocalFileDatasource] File path not accessible, trying to read as bytes...');
            // Try to get bytes if path is not accessible
            try {
              final bytes = await fileEntity.readAsBytes();
              return PlatformFile(
                name: file.name,
                size: bytes.length,
                path: null,
                bytes: bytes,
              );
            } catch (e) {
              print('[LocalFileDatasource] Could not read file as bytes: $e');
            }
          }
        }

        // If we reach here, we have a file but no way to access it
        if (file.bytes == null) {
          throw Exception(
              'Selected file is not accessible and no data is available');
        }

        return file;
      }

      print('[LocalFileDatasource] No file selected');
      return null;
    } catch (e) {
      print('[LocalFileDatasource] Error picking file: $e');

      if (Platform.isMacOS && e.toString().contains('not permitted')) {
        throw Exception(
            'File access not permitted. Please check macOS privacy settings and app entitlements.');
      }

      rethrow;
    }
  }
}
