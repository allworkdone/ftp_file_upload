import '../repositories/file_manager_repository.dart';
import '../entities/ftp_folder.dart';

class GetFoldersUsecase {
  final FileManagerRepository _repo;
  GetFoldersUsecase(this._repo);

  Future<List<FTPFolder>> call(String path) => _repo.getFolders(path);
}
