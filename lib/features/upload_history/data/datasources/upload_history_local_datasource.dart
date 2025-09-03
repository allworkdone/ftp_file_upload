import 'package:hive/hive.dart';

import '../../../../shared/data/providers/hive_provider.dart';
import '../../domain/entities/upload_record.dart';

abstract class UploadHistoryLocalDatasource {
  Future<List<UploadRecord>> getAll();
  Future<void> save(UploadRecord record);
  Future<void> clear();
}

class UploadHistoryLocalDatasourceImpl implements UploadHistoryLocalDatasource {
  final HiveProvider _hiveProvider;
  static const String _boxName = 'upload_history';

  UploadHistoryLocalDatasourceImpl(this._hiveProvider);

  Future<Box<dynamic>> _box() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await _hiveProvider.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  @override
  Future<void> clear() async {
    final box = await _box();
    await box.clear();
  }

  @override
  Future<List<UploadRecord>> getAll() async {
    final box = await _box();
    final list = <UploadRecord>[];
    for (final key in box.keys) {
      final m = box.get(key);
      if (m is Map) {
        list.add(_fromMap(m));
      }
    }
    list.sort((a, b) => b.uploadTime.compareTo(a.uploadTime));
    return list;
  }

  @override
  Future<void> save(UploadRecord record) async {
    final box = await _box();
    await box.put(record.id, _toMap(record));
  }

  Map<String, dynamic> _toMap(UploadRecord r) => {
        'id': r.id,
        'fileName': r.fileName,
        'originalFilePath': r.originalFilePath,
        'targetFolderPath': r.targetFolderPath,
        'generatedUrl': r.generatedUrl,
        'fileSize': r.fileSize,
        'uploadTime': r.uploadTime.toIso8601String(),
        'uploadDuration': r.uploadDuration.inMilliseconds,
        'isSuccessful': r.isSuccessful,
        'errorMessage': r.errorMessage,
      };

  UploadRecord _fromMap(Map map) => UploadRecord(
        id: map['id'] as String,
        fileName: map['fileName'] as String,
        originalFilePath: map['originalFilePath'] as String,
        targetFolderPath: map['targetFolderPath'] as String,
        generatedUrl: map['generatedUrl'] as String,
        fileSize: map['fileSize'] as int,
        uploadTime: DateTime.parse(map['uploadTime'] as String),
        uploadDuration: Duration(milliseconds: (map['uploadDuration'] as int?) ?? 0),
        isSuccessful: map['isSuccessful'] as bool? ?? true,
        errorMessage: map['errorMessage'] as String?,
      );
}

