import '../repositories/file_manager_repository.dart';

class CreateFolderUsecase {
  final FileManagerRepository _repo;
  CreateFolderUsecase(this._repo);

  Future<void> call(String path) => _repo.createFolder(path);
}
