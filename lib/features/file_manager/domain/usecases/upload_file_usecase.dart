import '../repositories/file_manager_repository.dart';
import '../entities/upload_progress.dart';
import '../entities/upload_cancel_token.dart';

class UploadFileUsecase {
  final FileManagerRepository _repo;
  UploadFileUsecase(this._repo);

  Stream<UploadProgress> call(String localPath, String remotePath, {UploadCancelToken? cancelToken}) =>
      _repo.uploadFile(localPath, remotePath, cancelToken: cancelToken);
}
