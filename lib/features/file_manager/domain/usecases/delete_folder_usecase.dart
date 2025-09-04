import '../repositories/file_manager_repository.dart';

class DeleteFolderUsecase {
  final FileManagerRepository _repo;
  DeleteFolderUsecase(this._repo);

  Future<void> call(String remoteFolderPath) =>
      _repo.deleteFolder(remoteFolderPath);
}
