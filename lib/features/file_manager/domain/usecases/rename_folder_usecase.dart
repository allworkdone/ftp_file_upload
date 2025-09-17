import '../repositories/file_manager_repository.dart';

class RenameFolderUsecase {
  final FileManagerRepository _repo;
  RenameFolderUsecase(this._repo);

  Future<void> call(String oldPath, String newPath) => _repo.renameFolder(oldPath, newPath);
}