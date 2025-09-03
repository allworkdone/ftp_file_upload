import '../repositories/file_manager_repository.dart';

class DeleteFileUsecase {
  final FileManagerRepository _repo;
  DeleteFileUsecase(this._repo);

  Future<void> call(String remoteFilePath) => _repo.deleteFile(remoteFilePath);
}
