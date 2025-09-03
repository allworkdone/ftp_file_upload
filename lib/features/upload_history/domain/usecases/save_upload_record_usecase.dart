import '../entities/upload_record.dart';
import '../repositories/upload_history_repository.dart';

class SaveUploadRecordUsecase {
  final UploadHistoryRepository _repo;
  SaveUploadRecordUsecase(this._repo);

  Future<void> call(UploadRecord record) => _repo.save(record);
}

