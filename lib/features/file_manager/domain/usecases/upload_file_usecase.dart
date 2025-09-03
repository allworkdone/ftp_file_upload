import '../repositories/file_manager_repository.dart';
import '../entities/upload_progress.dart';

class UploadFileUsecase {
  final FileManagerRepository _repo;
  UploadFileUsecase(this._repo);

  Stream<UploadProgress> call(String localPath, String remotePath) =>
      _repo.uploadFile(localPath, remotePath);
}
