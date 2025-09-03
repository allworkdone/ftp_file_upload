import '../../domain/entities/upload_record.dart';
import '../../domain/repositories/upload_history_repository.dart';
import '../datasources/upload_history_local_datasource.dart';

class UploadHistoryRepositoryImpl implements UploadHistoryRepository {
  final UploadHistoryLocalDatasource _local;
  UploadHistoryRepositoryImpl(this._local);

  @override
  Future<void> clear() => _local.clear();

  @override
  Future<List<UploadRecord>> getAll() => _local.getAll();

  @override
  Future<void> save(UploadRecord record) => _local.save(record);
}

