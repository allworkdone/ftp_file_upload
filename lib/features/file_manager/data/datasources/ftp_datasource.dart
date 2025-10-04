import 'dart:io';
import '../../../authentication/domain/entities/ftp_credentials.dart';
import '../../domain/entities/ftp_folder.dart';
import '../../domain/entities/ftp_file.dart';
import '../../../../core/services/ftp_service.dart';

abstract class FTPDatasource {
  Future<List<FTPFolder>> listFolders(FTPCredentials creds, String path);
  Future<List<FTPFile>> listFiles(FTPCredentials creds, String path);
  Future<void> createFolder(FTPCredentials creds, String path);
  Future<void> uploadFile(
    FTPCredentials creds,
    File file,
    String remotePath, {
    dynamic onProgress,
  });
  Future<void> deleteFile(FTPCredentials creds, String remotePath);
  Future<void> deleteFolder(
      FTPCredentials credentials, String remoteFolderPath);
  Future<String> downloadFile(FTPCredentials credentials, String remoteFilePath,
      String localDirectoryPath);
}

class FTPDatasourceImpl implements FTPDatasource {
  final FTPService _ftpService = FTPService();

   @override
 Future<List<FTPFolder>> listFolders(FTPCredentials creds, String path) async {
    print('FTPDatasource.listFolders: Attempting to list folders for path: $path');
    print('FTPDatasource.listFolders: Credentials - Host: ${creds.hostname}, Port: ${creds.port}, Username: ${creds.username}, Secure: ${creds.isSecure}');
    print('FTPDatasource.listFolders: FTPService connected state: ${_ftpService.isConnected}');
    
    // Ensure we're using a proper path format
    String normalizedPath = _normalizePath(path);
    print('FTPDatasource.listFolders: Normalized path: $normalizedPath');
    
    try {
      // List directory contents
      final entries = await _ftpService.listDirectory(normalizedPath, creds);
      
      // Filter for directories only
      final folders = entries
          .where((entry) => entry.isDirectory && entry.name != '.' && entry.name != '..')
          .map((entry) => FTPFolder(
                name: entry.name,
                path: entry.path, // Use the full path from the plugin's FtpFile
              ))
          .toList();
      
      print('FTPDatasource.listFolders: Found ${folders.length} folders');
      return folders;
    } catch (e) {
      print('FTPDatasource.listFolders: Error listing folders: $e');
      rethrow;
    }
  }

  @override
  Future<List<FTPFile>> listFiles(FTPCredentials creds, String path) async {
    print('FTPDatasource.listFiles: Attempting to list files for path: $path');
    print('FTPDatasource.listFiles: Credentials - Host: ${creds.hostname}, Port: ${creds.port}, Username: ${creds.username}, Secure: ${creds.isSecure}');
    print('FTPDatasource.listFiles: FTPService connected state: ${_ftpService.isConnected}');
    
    // Ensure we're using a proper path format
    String normalizedPath = _normalizePath(path);
    print('FTPDatasource.listFiles: Normalized path: $normalizedPath');
    
    try {
      // List directory contents
      final entries = await _ftpService.listDirectory(normalizedPath, creds);
      
      // Filter for files only (excluding . and .. which should be directories anyway)
      final files = entries
          .where((entry) => !entry.isDirectory && entry.name != '.' && entry.name != '..')
          .map((entry) => FTPFile(
                name: entry.name,
                path: entry.path, // Use the full path from the plugin's FtpFile
                type: FTPFileType.file,
                size: entry.size,
              ))
          .toList();
      
      print('FTPDatasource.listFiles: Found ${files.length} files');
      return files;
    } catch (e) {
      print('FTPDatasource.listFiles: Error listing files: $e');
      rethrow;
    }
 }

  @override
  Future<void> createFolder(FTPCredentials creds, String path) async {
    await _ftpService.createDirectory(path, creds);
  }

  @override
  Future<void> uploadFile(
    FTPCredentials creds,
    File file,
    String remotePath, {
    dynamic onProgress,
  }) async {
    // Convert onProgress to the expected format for the new plugin
    Function(double)? progressCallback;
    if (onProgress != null) {
      progressCallback = (progress) {
        onProgress(progress * 10); // Convert to percentage
      };
    }

    await _ftpService.uploadFile(
      localPath: file.path,
      remotePath: remotePath,
      onProgress: progressCallback,
      credentials: creds,
    );
  }

  @override
  Future<void> deleteFile(FTPCredentials creds, String remotePath) async {
    await _ftpService.deleteFile(remotePath, creds);
  }

  @override
  Future<void> deleteFolder(
      FTPCredentials credentials, String remoteFolderPath) async {
    // Normalize the path
    String normalizedPath = _normalizePath(remoteFolderPath);

    // First, list the contents of the folder to delete files/subfolders recursively
    try {
      final contents = await _ftpService.listDirectory(normalizedPath, credentials);

      for (final item in contents) {
        // Use the full path from the plugin's FtpFile
        String itemPath = item.path;

        if (item.isDirectory) {
          // Recursively delete subdirectory
          await deleteFolder(credentials, itemPath);
        } else {
          // Delete file
          await _ftpService.deleteFile(itemPath, credentials);
        }
      }
    } catch (e) {
      // If listing fails, the folder might be empty or inaccessible
      print('Could not list folder contents: $e');
    }

    // Finally, delete the empty folder
    await _ftpService.deleteDirectory(remoteFolderPath, credentials);
  }

  @override
  Future<String> downloadFile(FTPCredentials credentials, String remoteFilePath,
      String localDirectoryPath) async {
    // Extract filename from remote path
    final fileName = remoteFilePath.split('/').last;
    final localFilePath = '$localDirectoryPath/$fileName';

    // Create local file
    final localFile = File(localFilePath);

    // Ensure parent directory exists
    await localFile.parent.create(recursive: true);

    print('Attempting to download $remoteFilePath to $localFilePath');

    // Download the file
    final downloaded = await _ftpService.downloadFile(
      remotePath: remoteFilePath,
      localPath: localFilePath,
      credentials: credentials,
    );

    if (!downloaded) {
      print('Failed to download file: $remoteFilePath');
      throw Exception('Failed to download file');
    }

    print('Successfully downloaded $remoteFilePath to $localFilePath');
    return localFilePath;
  }

   /// Normalizes the path to ensure consistent format for FTP operations
 String _normalizePath(String path) {
    print('FTPDatasource._normalizePath: Input path: $path');
    
    if (path.isEmpty || path == '/') {
      print('FTPDatasource._normalizePath: Returning root path: /');
      return '/';
    }

    // Ensure path starts with '/' but doesn't have multiple leading slashes
    String normalized = path.replaceAll('//', '/');
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    
    // Remove trailing slash if it exists (except for root)
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    // Don't add trailing slash as it might cause issues with the plugin
    print('FTPDatasource._normalizePath: Normalized path: $normalized');
    return normalized;
  }
}
