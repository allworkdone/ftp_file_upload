import 'package:hive/hive.dart';
import 'package:file_upload/features/file_manager/domain/entities/ftp_file.dart';
import 'package:file_upload/features/file_manager/domain/entities/ftp_folder.dart';

class FolderCacheService {
  static const String _folderCacheBox = 'folder_cache';
  
  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_folderCacheBox);
  }

  Future<void> cacheFolderContents(String path, List<FTPFolder> folders, List<FTPFile> files) async {
    final folderData = folders.map((f) => {
      'name': f.name,
      'path': f.path,
      'createdDate': f.createdDate?.millisecondsSinceEpoch,
    }).toList();

    final fileData = files.map((f) => {
      'name': f.name,
      'path': f.path,
      'type': f.type.index,
      'size': f.size,
      'modifiedDate': f.modifiedDate?.millisecondsSinceEpoch,
      'extension': f.extension,
    }).toList();

    await _box.put(path, {
      'folders': folderData,
      'files': fileData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Map<String, dynamic>? getCachedFolderContents(String path) {
    return _box.get(path);
  }

  bool hasValidCache(String path, {int maxAgeMinutes = 5}) {
    final cachedData = _box.get(path);
    if (cachedData == null) return false;

    final timestamp = cachedData['timestamp'] as int?;
    if (timestamp == null) return false;

    final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
    return cacheAge < (maxAgeMinutes * 60 * 100); // Convert minutes to milliseconds
 }

  Future<void> clearCache() async {
    await _box.clear();
  }

  Future<void> clearCacheForPath(String path) async {
    await _box.delete(path);
  }

  List<String> get allCachedPaths {
    return _box.keys.cast<String>().toList();
  }
}
