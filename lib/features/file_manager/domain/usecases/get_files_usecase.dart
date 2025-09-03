import '../entities/ftp_file.dart';
import '../repositories/file_manager_repository.dart';

class GetFilesUsecase {
  final FileManagerRepository _repo;
  GetFilesUsecase(this._repo);

  Future<List<FTPFile>> call(String path) => _repo.getFiles(path);
}

