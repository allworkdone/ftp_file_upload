import '../repositories/file_manager_repository.dart';

class DownloadFileUsecase {
  final FileManagerRepository _repo;
  DownloadFileUsecase(this._repo);

  Future<String> call(String remoteFilePath, String localDirectoryPath) =>
      _repo.downloadFile(remoteFilePath, localDirectoryPath);
}
