import '../entities/ftp_folder.dart';
import '../entities/ftp_file.dart';
import '../entities/upload_progress.dart';

abstract class FileManagerRepository {
  Future<List<FTPFolder>> getFolders(String path);
  Future<List<FTPFile>> getFiles(String path);
  Future<void> createFolder(String path);
  Stream<UploadProgress> uploadFile(String localPath, String remotePath);
  Future<void> deleteFile(String remoteFilePath);
  Future<void> deleteFolder(String remoteFolderPath);
  Future<String> downloadFile(String remoteFilePath, String localDirectoryPath, {Function(double, double)? onProgress, Function? onCancel});
  Future<void> renameFile(String oldPath, String newPath);
  Future<void> renameFolder(String oldPath, String newPath);
}
