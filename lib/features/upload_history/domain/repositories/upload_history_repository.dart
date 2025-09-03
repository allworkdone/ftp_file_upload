import '../entities/upload_record.dart';

abstract class UploadHistoryRepository {
  Future<List<UploadRecord>> getAll();
  Future<void> save(UploadRecord record);
  Future<void> clear();
}

