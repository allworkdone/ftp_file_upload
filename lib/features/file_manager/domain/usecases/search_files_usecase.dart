import '../entities/ftp_file.dart';
import '../entities/ftp_folder.dart';
import '../repositories/file_manager_repository.dart';
import 'package:logger/logger.dart';

class SearchFilesUsecase {
  final FileManagerRepository _repo;
  final Logger _logger = Logger();
  
  SearchFilesUsecase(this._repo);

  Future<List<SearchResult>> call(String searchTerm, String rootPath) async {
    _logger.i('Starting search for "$searchTerm" in "$rootPath"');
    final results = <SearchResult>[];
    await _searchRecursively(searchTerm, rootPath, results);
    _logger.i('Search completed. Found ${results.length} results');
    return results;
  }

  Future<void> _searchRecursively(
      String searchTerm, String currentPath, List<SearchResult> results) async {
    try {
      _logger.d('Searching in path: $currentPath');
      
      // Get files and folders in current path
      final files = await _repo.getFiles(currentPath);
      final folders = await _repo.getFolders(currentPath);

      _logger.d('Found ${files.length} files and ${folders.length} folders in $currentPath');

      // Search in files
      for (final file in files) {
        if (file.name.toLowerCase().contains(searchTerm.toLowerCase())) {
          _logger.d('Found matching file: ${file.name}');
          results.add(SearchResult.file(file, currentPath));
        }
      }

      // Search in folders
      for (final folder in folders) {
        if (folder.name.toLowerCase().contains(searchTerm.toLowerCase())) {
          _logger.d('Found matching folder: ${folder.name}');
          results.add(SearchResult.folder(folder, currentPath));
        }
        // Recursively search in subfolders
        // Add a small delay to prevent blocking the UI
        await Future.delayed(Duration(milliseconds: 1));
        await _searchRecursively(searchTerm, folder.fullPath, results);
      }
    } catch (e) {
      // Continue searching even if one folder fails
      _logger.e('Failed to search in $currentPath: $e');
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