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
      String localDirectoryPath);
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
    } catch (_) {}
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
          .map((e) => FTPFolder(name: e.name ?? '', path: path))
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
              ))
          .toList();
      return files;
    } finally {
      await ftp.disconnect();
    }
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
      String localDirectoryPath) async {
    final ftpConnect = FTPConnect(
      credentials.hostname,
      user: credentials.username,
      pass: credentials.password,
      port: credentials.port,
    );

    try {
      await ftpConnect.connect();

      // Extract filename from remote path
      final fileName = remoteFilePath.split('/').last;
      final localFilePath = '$localDirectoryPath/$fileName';

      // Create local file
      final localFile = File(localFilePath);

      // Ensure parent directory exists
      await localFile.parent.create(recursive: true);

      // Download the file
      final downloaded =
          await ftpConnect.downloadFile(remoteFilePath, localFile);

      if (!downloaded) {
        throw Exception('Failed to download file');
      }

      return localFilePath;
    } catch (e) {
      throw Exception('Failed to download file: $e');
    } finally {
      try {
        await ftpConnect.disconnect();
      } catch (e) {
        print('Error disconnecting: $e');
      }
    }
  }

  Future<String> downloadFileWithRetry(FTPCredentials credentials,
      String remoteFilePath, String localDirectoryPath,
      {int maxRetries = 3}) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await downloadFile(
            credentials, remoteFilePath, localDirectoryPath);
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
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
}
