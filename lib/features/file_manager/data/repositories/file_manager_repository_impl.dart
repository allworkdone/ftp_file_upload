import 'dart:io';

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

class FileManagerRepositoryImpl implements FileManagerRepository {
  final FTPDatasource ftpDatasource;
  final LocalFileDatasource localFileDatasource;
  final NetworkInfo networkInfo;

  FileManagerRepositoryImpl({
    required this.ftpDatasource,
    required this.localFileDatasource,
    required this.networkInfo,
  });

  Future<FTPCredentials?> _creds() => getIt<GetCredentialsUsecase>()();

  @override
  Future<void> createFolder(String path) async {
    final creds = await _creds();
    if (creds == null) throw Exception('No credentials');
    await ftpDatasource.createFolder(creds, path);
  }

  @override
  Future<List<FTPFolder>> getFolders(String path) async {
    final creds = await _creds();
    if (creds == null) throw Exception('No credentials');
    return ftpDatasource.listFolders(creds, path);
  }

  @override
  Future<List<FTPFile>> getFiles(String path) async {
    final creds = await _creds();
    if (creds == null) throw Exception('No credentials');
    return ftpDatasource.listFiles(creds, path);
  }

  @override
  Stream<UploadProgress> uploadFile(String localPath, String remotePath) async* {
    final creds = await _creds();
    if (creds == null) throw Exception('No credentials');
    if (!await networkInfo.isConnected) throw Exception('No internet');

    final file = File(localPath);
    final total = await file.length();
    final fileName = file.path.split('/').last;
    yield UploadProgress(
      fileName: fileName,
      filePath: localPath,
      targetFolderPath: remotePath,
      totalBytes: total,
      uploadedBytes: 0,
      status: UploadStatus.uploading,
      startTime: DateTime.now(),
    );
    final start = DateTime.now();
    await ftpDatasource.uploadFile(creds, file, remotePath);
    yield UploadProgress(
      fileName: fileName,
      filePath: localPath,
      targetFolderPath: remotePath,
      totalBytes: total,
      uploadedBytes: total,
      status: UploadStatus.completed,
      startTime: start,
      endTime: DateTime.now(),
    );
  }

  @override
  Future<void> deleteFile(String remoteFilePath) async {
    final creds = await _creds();
    if (creds == null) throw Exception('No credentials');
    await ftpDatasource.deleteFile(creds, remoteFilePath);
  }
}
