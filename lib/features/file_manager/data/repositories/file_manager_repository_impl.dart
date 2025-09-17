import 'dart:io';
import 'dart:async';

import '../../../authentication/domain/entities/ftp_credentials.dart';
import '../../../authentication/domain/usecases/get_credentials_usecase.dart';
import '../../domain/entities/ftp_folder.dart';
import '../../domain/entities/upload_progress.dart';
import '../../domain/entities/ftp_file.dart';
import '../../domain/repositories/file_manager_repository.dart';
import '../datasources/ftp_datasource.dart';
import '../datasources/local_file_datasource.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/error/exceptions.dart';

class FileManagerRepositoryImpl implements FileManagerRepository {
  final FTPDatasource ftpDatasource;
  final LocalFileDatasource localFileDatasource;
  final NetworkInfo networkInfo;

  FileManagerRepositoryImpl({
    required this.ftpDatasource,
    required this.localFileDatasource,
    required this.networkInfo,
  });

  @override
  Future<void> renameFile(String oldPath, String newPath) async {
    if (!(await networkInfo.isConnected)) {
      throw const FTPException('No internet connection', FTPExceptionType.connection);
    }

    final credentials = await getIt<GetCredentialsUsecase>()();
    if (credentials == null) {
      throw const FTPException('No credentials found', FTPExceptionType.authentication);
    }
    
    await ftpDatasource.renameFile(credentials, oldPath, newPath);
  }

  @override
  Future<void> renameFolder(String oldPath, String newPath) async {
    if (!(await networkInfo.isConnected)) {
      throw const FTPException('No internet connection', FTPExceptionType.connection);
    }

    final credentials = await getIt<GetCredentialsUsecase>()();
    if (credentials == null) {
      throw const FTPException('No credentials found', FTPExceptionType.authentication);
    }
    
    await ftpDatasource.renameFolder(credentials, oldPath, newPath);
  }

  @override
  Future<void> createFolder(String path) async {
    final credentials = await getIt<GetCredentialsUsecase>()();
    if (credentials == null) {
      throw const FTPException('No credentials found', FTPExceptionType.authentication);
    }
    await ftpDatasource.createFolder(credentials, path);
  }

  @override
  Future<List<FTPFolder>> getFolders(String path) async {
    final credentials = await getIt<GetCredentialsUsecase>()();
    if (credentials == null) {
      throw const FTPException('No credentials found', FTPExceptionType.authentication);
    }
    return ftpDatasource.listFolders(credentials, path);
  }

  @override
  Future<List<FTPFile>> getFiles(String path) async {
    final credentials = await getIt<GetCredentialsUsecase>()();
    if (credentials == null) {
      throw const FTPException('No credentials found', FTPExceptionType.authentication);
    }
    return ftpDatasource.listFiles(credentials, path);
  }

  @override
  Stream<UploadProgress> uploadFile(String localPath, String remotePath) {
    final controller = StreamController<UploadProgress>();
    () async {
      final credentials = await getIt<GetCredentialsUsecase>()();
      if (credentials == null) {
        controller.addError(const FTPException('No credentials found', FTPExceptionType.authentication));
        await controller.close();
        return;
      }
      if (!await networkInfo.isConnected) {
        controller.addError(const FTPException('No internet connection', FTPExceptionType.connection));
        await controller.close();
        return;
      }

      final file = File(localPath);
      final total = await file.length();
      final fileName = file.path.split('/').last;
      final start = DateTime.now();

      controller.add(UploadProgress(
        fileName: fileName,
        filePath: localPath,
        targetFolderPath: remotePath,
        totalBytes: total,
        uploadedBytes: 0,
        status: UploadStatus.uploading,
        startTime: start,
      ));

      try {
        final dynamic progressCb = (a, [b, c]) {
          int sent = 0;
          int t = total;
          if (a is int && b is int) {
            sent = a;
            t = b == 0 ? total : b;
          } else if (a is double && b is double) {
            sent = a.toInt();
            t = b == 0 ? total : b.toInt();
          } else if (b is int && c is int) {
            sent = b;
            t = c == 0 ? total : c;
          }
          controller.add(UploadProgress(
            fileName: fileName,
            filePath: localPath,
            targetFolderPath: remotePath,
            totalBytes: t,
            uploadedBytes: sent,
            status: UploadStatus.uploading,
            startTime: start,
          ));
        };

        await ftpDatasource.uploadFile(
          credentials,
          file,
          remotePath,
          onProgress: progressCb,
        );
        controller.add(UploadProgress(
          fileName: fileName,
          filePath: localPath,
          targetFolderPath: remotePath,
          totalBytes: total,
          uploadedBytes: total,
          status: UploadStatus.completed,
          startTime: start,
          endTime: DateTime.now(),
        ));
      } catch (e) {
        controller.add(UploadProgress(
          fileName: fileName,
          filePath: localPath,
          targetFolderPath: remotePath,
          totalBytes: total,
          uploadedBytes: 0,
          status: UploadStatus.failed,
          errorMessage: e.toString(),
          startTime: start,
          endTime: DateTime.now(),
        ));
        controller.addError(e);
      } finally {
        await controller.close();
      }
    }();
    return controller.stream;
  }

  @override
  Future<void> deleteFile(String remoteFilePath) async {
    final credentials = await getIt<GetCredentialsUsecase>()();
    if (credentials == null) {
      throw const FTPException('No credentials found', FTPExceptionType.authentication);
    }
    await ftpDatasource.deleteFile(credentials, remoteFilePath);
  }

  @override
  Future<void> deleteFolder(String remoteFolderPath) async {
    final credentials = await getIt<GetCredentialsUsecase>()();
    if (credentials == null) {
      throw const FTPException('No credentials found', FTPExceptionType.authentication);
    }
    await ftpDatasource.deleteFolder(credentials, remoteFolderPath);
  }

  @override
  Future<String> downloadFile(
      String remoteFilePath, String localDirectoryPath) async {
    final credentials = await getIt<GetCredentialsUsecase>()();
    if (credentials == null) {
      throw const FTPException('No credentials found', FTPExceptionType.authentication);
    }

    if (!await networkInfo.isConnected) {
      throw const FTPException('No internet connection', FTPExceptionType.connection);
    }

    return await ftpDatasource.downloadFile(
        credentials, remoteFilePath, localDirectoryPath);
  }
}
