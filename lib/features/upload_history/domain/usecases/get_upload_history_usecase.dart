import '../entities/upload_record.dart';
import '../repositories/upload_history_repository.dart';

class GetUploadHistoryUsecase {
  final UploadHistoryRepository _repo;
  GetUploadHistoryUsecase(this._repo);

  Future<List<UploadRecord>> call() => _repo.getAll();
}

