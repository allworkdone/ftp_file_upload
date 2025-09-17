import '../repositories/file_manager_repository.dart';

class RenameFileUsecase {
  final FileManagerRepository _repo;
  RenameFileUsecase(this._repo);

  Future<void> call(String oldPath, String newPath) => _repo.renameFile(oldPath, newPath);
}