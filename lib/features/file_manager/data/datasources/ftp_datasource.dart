import 'dart:io';

import 'package:ftpconnect/ftpconnect.dart';

import '../../../authentication/domain/entities/ftp_credentials.dart';
import '../../domain/entities/ftp_folder.dart';
import '../../domain/entities/ftp_file.dart';

abstract class FTPDatasource {
  Future<List<FTPFolder>> listFolders(FTPCredentials creds, String path);
  Future<List<FTPFile>> listFiles(FTPCredentials creds, String path);
  Future<void> createFolder(FTPCredentials creds, String path);
  Future<void> uploadFile(FTPCredentials creds, File file, String remotePath);
  Future<void> deleteFile(FTPCredentials creds, String remotePath);
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
      FTPCredentials creds, File file, String remotePath) async {
    final ftp = await _client(creds);
    try {
      await ftp.uploadFile(file, sRemoteName: remotePath);
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
}
