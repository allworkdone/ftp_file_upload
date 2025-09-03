import '../repositories/upload_history_repository.dart';

class ClearHistoryUsecase {
  final UploadHistoryRepository _repo;
  ClearHistoryUsecase(this._repo);

  Future<void> call() => _repo.clear();
}

