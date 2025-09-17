import '../entities/ftp_file.dart';
import '../entities/ftp_folder.dart';
import '../repositories/file_manager_repository.dart';

class SearchFilesUsecase {
  final FileManagerRepository _repo;
  SearchFilesUsecase(this._repo);

  Future<List<SearchResult>> call(String searchTerm, String rootPath) async {
    final results = <SearchResult>[];
    await _searchRecursively(searchTerm, rootPath, results);
    return results;
  }

  Future<void> _searchRecursively(
      String searchTerm, String currentPath, List<SearchResult> results) async {
    try {
      // Get files and folders in current path
      final files = await _repo.getFiles(currentPath);
      final folders = await _repo.getFolders(currentPath);

      // Search in files
      for (final file in files) {
        if (file.name.toLowerCase().contains(searchTerm.toLowerCase())) {
          results.add(SearchResult.file(file, currentPath));
        }
      }

      // Search in folders
      for (final folder in folders) {
        if (folder.name.toLowerCase().contains(searchTerm.toLowerCase())) {
          results.add(SearchResult.folder(folder, currentPath));
        }
        // Recursively search in subfolders
        await _searchRecursively(searchTerm, folder.fullPath, results);
      }
    } catch (e) {
      // Continue searching even if one folder fails
      print('Failed to search in $currentPath: $e');
    }
  }
}

class SearchResult {
  final String name;
  final String path;
  final String parentPath;
  final bool isFile;
  final int? size;
  final String? extension;

  SearchResult.file(FTPFile file, String parentPath)
      : name = file.name,
        path = file.fullPath,
        parentPath = parentPath,
        isFile = true,
        size = file.size,
        extension = file.extension;

  SearchResult.folder(FTPFolder folder, String parentPath)
      : name = folder.name,
        path = folder.fullPath,
        parentPath = parentPath,
        isFile = false,
        size = null,
        extension = null;
}