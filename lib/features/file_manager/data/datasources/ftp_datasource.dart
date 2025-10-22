import 'dart:io';

import 'package:ftpconnect/ftpconnect.dart';

import '../../../authentication/domain/entities/ftp_credentials.dart';
import '../../domain/entities/ftp_folder.dart';
import '../../domain/entities/ftp_file.dart';

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
      String localDirectoryPath, {Function(double)? onProgress});
  Future<void> renameFile(FTPCredentials credentials, String oldPath, String newPath);
  Future<void> renameFolder(FTPCredentials credentials, String oldPath, String newPath);
}

class FTPDatasourceImpl implements FTPDatasource {
  Future<FTPConnect> _client(FTPCredentials c) async {
    final ftp = FTPConnect(
      c.hostname,
      user: c.username,
      pass: c.password,
      port: c.port,
      timeout: 30,
      securityType: c.isSecure ? SecurityType.FTPS : SecurityType.FTP,
    );
    await ftp.connect();
    // Force binary transfer when available to avoid corruption
    try {
      await (ftp as dynamic).setTransferType(TransferType.binary);
    } catch (e) {
      print('Failed to set binary transfer type: $e');
      // Optionally re-throw or handle more explicitly if this is critical
    }
    return ftp;
  }

  Future<void> _changeTo(FTPConnect ftp, String path) async {
    try {
      if (path.isEmpty || path == '/') {
        await ftp.changeDirectory('/');
      } else {
        await ftp.changeDirectory(path);
      }
    } catch (_) {
      // Ignore if server rejects; we'll try listing current directory
    }
  }

  @override
  Future<void> createFolder(FTPCredentials creds, String path) async {
    final ftp = await _client(creds);
    try {
      // Not all FTP servers support MKD on absolute path; try change dir then create
      try {
        await ftp.makeDirectory(path);
      } catch (_) {}
    } finally {
      await ftp.disconnect();
    }
  }

  @override
  Future<List<FTPFolder>> listFolders(FTPCredentials creds, String path) async {
    final ftp = await _client(creds);
    try {
      await _changeTo(ftp, path);
      final entries = await ftp.listDirectoryContent();
      final folders = entries
          .where((e) => e.type == FTPEntryType.DIR)
          .map((e) => FTPFolder(
                name: e.name ?? '',
                path: path,
                files: [], // We'll populate files only when needed for performance
                subFolders: [], // We'll populate subfolders only when needed for performance
              ))
          .toList();
      return folders;
    } finally {
      await ftp.disconnect();
    }
  }

  @override
  Future<List<FTPFile>> listFiles(FTPCredentials creds, String path) async {
    final ftp = await _client(creds);
    try {
      await _changeTo(ftp, path);
      final entries = await ftp.listDirectoryContent();
      final files = entries
          .where((e) => e.type == FTPEntryType.FILE)
          .map((e) => FTPFile(
                name: e.name ?? '',
                path: path,
                type: FTPFileType.file,
                size: e.size ?? 0, // Use the size from the FTP entry
                extension: _getExtension(e.name ?? ''), // Extract the file extension
              ))
          .toList();
      return files;
    } finally {
      await ftp.disconnect();
    }
  }

  // Helper method to extract file extension
  String? _getExtension(String fileName) {
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex != -1 && lastDotIndex < fileName.length - 1) {
      return fileName.substring(lastDotIndex + 1).toLowerCase();
    }
    return null;
  }

  @override
  Future<void> uploadFile(
    FTPCredentials creds,
    File file,
    String remotePath, {
    dynamic onProgress,
  }) async {
    final ftp = await _client(creds);
    try {
      // remotePath may include directories; change to that directory first
      String dir = '/';
      String name = remotePath;
      final idx = remotePath.replaceAll('\\', '/').lastIndexOf('/');
      if (idx >= 0) {
        dir = idx == 0 ? '/' : remotePath.substring(0, idx);
        name = remotePath.substring(idx + 1);
      }
      await _changeTo(ftp, dir);
      await ftp.uploadFile(
        file,
        sRemoteName: name,
        onProgress: onProgress,
      );
    } finally {
      await ftp.disconnect();
    }
  }

  @override
  Future<void> deleteFile(FTPCredentials creds, String remotePath) async {
    final ftp = await _client(creds);
    try {
      await ftp.deleteFile(remotePath);
    } finally {
      await ftp.disconnect();
    }
  }

  @override
  Future<void> deleteFolder(
      FTPCredentials credentials, String remoteFolderPath) async {
    final ftpConnect = FTPConnect(
      credentials.hostname,
      user: credentials.username,
      pass: credentials.password,
      port: credentials.port,
    );

    try {
      await ftpConnect.connect();

      // First, try to list contents of the folder to delete files/subfolders recursively
      try {
        final contents = await ftpConnect.listDirectoryContent();

        for (final item in contents) {
          final itemPath = remoteFolderPath.endsWith('/')
              ? '$remoteFolderPath${item.name}'
              : '$remoteFolderPath/${item.name}';

          if (item.type == FTPEntryType.DIR) {
            // Recursively delete subdirectory
            await deleteFolder(credentials, itemPath);
          } else {
            // Delete file
            await ftpConnect.deleteFile(itemPath);
          }
        }
      } catch (e) {
        // If listing fails, the folder might be empty or inaccessible
        print('Could not list folder contents: $e');
      }

      // Finally, delete the empty folder
      await ftpConnect.deleteDirectory(remoteFolderPath);
    } catch (e) {
      throw Exception('Failed to delete folder: $e');
    } finally {
      try {
        await ftpConnect.disconnect();
      } catch (e) {
        print('Error disconnecting: $e');
      }
    }
  }

  @override
  Future<String> downloadFile(FTPCredentials credentials, String remoteFilePath,
      String localDirectoryPath, {Function(double)? onProgress}) async {
    final ftpConnect = FTPConnect(
      credentials.hostname,
      user: credentials.username,
      pass: credentials.password,
      port: credentials.port,
    );

    try {
      await ftpConnect.connect();

      // Ensure binary transfer type for reliable downloads
      try {
        await (ftpConnect as dynamic).setTransferType(TransferType.binary);
      } catch (e) {
        print('Failed to set binary transfer type for download: $e');
        // Continue with download even if setting binary fails, but log it.
      }

      // Extract filename from remote path
      final fileName = remoteFilePath.split('/').last;
      final localFilePath = '$localDirectoryPath/$fileName';

      // Create local file
      final localFile = File(localFilePath);

      // Ensure parent directory exists
      await localFile.parent.create(recursive: true);

      print('Attempting to download $remoteFilePath to $localFilePath');

      // Download the file with progress callback if provided
      final downloaded = await ftpConnect.downloadFile(
        remoteFilePath, 
        localFile,
        onProgress: onProgress != null ? (a, [b = 0, c = 0]) {
          try {
            double progress = 0.0;
            if (a is int && b is int && b > 0) {
              progress = a.toDouble() / b.toDouble();
            } else if (a is double && b is double && b > 0) {
              progress = a / b;
            } else if (b is int && c is int && c > 0) {
              progress = b.toDouble() / c.toDouble();
            } else if (a is int && c is int && c > 0) {
              progress = a.toDouble() / c.toDouble();
            } else if (a is double && a >= 0.0 && a <= 1.0) {
              // If a is already a progress value between 0 and 1
              progress = a;
            }
            // Ensure progress is between 0 and 1
            progress = progress.clamp(0.0, 1.0);
            onProgress(progress);
          } catch (e) {
            // If there's an error calculating progress, just report 0
            onProgress(0.0);
          }
        } : null,
      );

      if (!downloaded) {
        print('FTPConnect.downloadFile returned false for $remoteFilePath');
        throw Exception('Failed to download file');
      }

      print('Successfully downloaded $remoteFilePath to $localFilePath');
      return localFilePath;
    } catch (e) {
      print('Error during file download: $e');
      throw Exception('Failed to download file: $e');
    } finally {
      try {
        await ftpConnect.disconnect();
      } catch (e) {
        print('Error disconnecting FTP client after download: $e');
      }
    }
  }

  @override
  Future<String> downloadFileWithRetry(FTPCredentials credentials,
      String remoteFilePath, String localDirectoryPath,
      {int maxRetries = 3, Function(double)? onProgress}) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await downloadFile(
            credentials, remoteFilePath, localDirectoryPath, onProgress: onProgress);
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        print('Download attempt $attempt failed: $e');
        if (attempt < maxRetries) {
          // Wait before retry (exponential backoff)
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
      }
    }

    throw lastException ??
        Exception('Download failed after $maxRetries attempts');
  }

  @override
  Future<void> renameFile(FTPCredentials credentials, String oldPath, String newPath) async {
    final ftpConnect = FTPConnect(
      credentials.hostname,
      user: credentials.username,
      pass: credentials.password,
      port: credentials.port,
    );

    try {
      await ftpConnect.connect();

      // Rename the file using the FTP RNFR (rename from) and RNTO (rename to) commands
      await ftpConnect.rename(oldPath, newPath);
    } catch (e) {
      print('Error during file rename: $e');
      throw Exception('Failed to rename file: $e');
    } finally {
      try {
        await ftpConnect.disconnect();
      } catch (e) {
        print('Error disconnecting FTP client after rename: $e');
      }
    }
  }

  @override
  Future<void> renameFolder(FTPCredentials credentials, String oldPath, String newPath) async {
    final ftpConnect = FTPConnect(
      credentials.hostname,
      user: credentials.username,
      pass: credentials.password,
      port: credentials.port,
    );

    try {
      await ftpConnect.connect();

      // Rename the folder using the FTP RNFR (rename from) and RNTO (rename to) commands
      await ftpConnect.rename(oldPath, newPath);
    } catch (e) {
      print('Error during folder rename: $e');
      throw Exception('Failed to rename folder: $e');
    } finally {
      try {
        await ftpConnect.disconnect();
      } catch (e) {
        print('Error disconnecting FTP client after rename: $e');
      }
    }
  }
}
