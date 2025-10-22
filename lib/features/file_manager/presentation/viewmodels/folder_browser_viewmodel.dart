import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ftp_folder.dart';
import '../../domain/entities/ftp_file.dart';
import '../../domain/usecases/get_folders_usecase.dart';
import '../../domain/usecases/get_files_usecase.dart';
import '../../../../core/di/injection.dart';

class FolderBrowserState {
  final List<FTPFolder> folders;
  final List<FTPFile> files;
  final List<FTPFolder> allFolders; // Store all folders for search
  final List<FTPFile> allFiles; // Store all files for search
  final bool loading;
  final String? error;
  final String? searchQuery;
  final FolderSortOption sortOption;

  const FolderBrowserState({
    this.folders = const [],
    this.files = const [],
    this.allFolders = const [],
    this.allFiles = const [],
    this.loading = false,
    this.error,
    this.searchQuery,
    this.sortOption = FolderSortOption.name,
  });

  FolderBrowserState copyWith({
    List<FTPFolder>? folders,
    List<FTPFile>? files,
    List<FTPFolder>? allFolders,
    List<FTPFile>? allFiles,
    bool? loading,
    String? error,
    String? searchQuery,
    FolderSortOption? sortOption,
  }) => FolderBrowserState(
        folders: folders ?? this.folders,
        files: files ?? this.files,
        allFolders: allFolders ?? this.allFolders,
        allFiles: allFiles ?? this.allFiles,
        loading: loading ?? this.loading,
        error: error,
        searchQuery: searchQuery ?? this.searchQuery,
        sortOption: sortOption ?? this.sortOption,
      );
}

enum FolderSortOption { name, nameReverse }

class FolderBrowserViewModel extends StateNotifier<FolderBrowserState> {
  final GetFoldersUsecase _getFolders;
  final GetFilesUsecase _getFiles;

  FolderBrowserViewModel()
      : _getFolders = getIt<GetFoldersUsecase>(),
        _getFiles = getIt<GetFilesUsecase>(),
        super(const FolderBrowserState());

  Future<void> load(String folderPath) async {
    state = state.copyWith(loading: true, error: null, searchQuery: null);
    try {
      final results = await Future.wait([
        _getFolders(folderPath),
        _getFiles(folderPath),
      ]);
      final folders = results[0] as List<FTPFolder>;
      final files = results[1] as List<FTPFile>;
      
      state = state.copyWith(
        allFolders: folders,
        allFiles: files,
        loading: false,
        error: null,
      );
      _applySearchAndSort(); // Apply search and sort after loading
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applySearchAndSort();
  }

  void setSortOption(FolderSortOption option) {
    state = state.copyWith(sortOption: option);
    _applySearchAndSort();
  }

  void _applySearchAndSort() {
    List<FTPFolder> folderResult = List.from(state.allFolders);
    List<FTPFile> fileResult = List.from(state.allFiles);
    
    // Apply search filter
    if (state.searchQuery != null && state.searchQuery!.isNotEmpty) {
      folderResult = folderResult.where((folder) => 
          folder.name.toLowerCase().contains(state.searchQuery!.toLowerCase())).toList();
      fileResult = fileResult.where((file) => 
          file.name.toLowerCase().contains(state.searchQuery!.toLowerCase())).toList();
    }
    
    // Apply sorting to folders
    switch (state.sortOption) {
      case FolderSortOption.name:
        folderResult.sort((a, b) => a.name.compareTo(b.name));
        fileResult.sort((a, b) => a.name.compareTo(b.name));
        break;
      case FolderSortOption.nameReverse:
        folderResult.sort((a, b) => b.name.compareTo(a.name));
        fileResult.sort((a, b) => b.name.compareTo(a.name));
        break;
    }
    
    state = state.copyWith(folders: folderResult, files: fileResult);
  }
}

final folderBrowserViewModelProvider =
    StateNotifierProvider<FolderBrowserViewModel, FolderBrowserState>((ref) => FolderBrowserViewModel());
