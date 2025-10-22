import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ftp_folder.dart';
import '../../domain/usecases/get_folders_usecase.dart';
import '../../domain/usecases/create_folder_usecase.dart';
import '../../../../core/di/injection.dart';

class FileManagerState {
  final String currentPath;
  final List<FTPFolder> folders;
  final List<FTPFolder> allFolders; // Store all folders for search
  final bool loading;
  final String? error;
  final String? searchQuery;
  final FolderSortOption sortOption;

  const FileManagerState({
    this.currentPath = '/',
    this.folders = const [],
    this.allFolders = const [],
    this.loading = false,
    this.error,
    this.searchQuery,
    this.sortOption = FolderSortOption.name,
  });

  FileManagerState copyWith({
    String? currentPath,
    List<FTPFolder>? folders,
    List<FTPFolder>? allFolders,
    bool? loading,
    String? error,
    String? searchQuery,
    FolderSortOption? sortOption,
  }) => FileManagerState(
        currentPath: currentPath ?? this.currentPath,
        folders: folders ?? this.folders,
        allFolders: allFolders ?? this.allFolders,
        loading: loading ?? this.loading,
        error: error,
        searchQuery: searchQuery ?? this.searchQuery,
        sortOption: sortOption ?? this.sortOption,
      );
}

enum FolderSortOption { name, nameReverse }

class FileManagerViewModel extends StateNotifier<FileManagerState> {
  final GetFoldersUsecase _getFolders;
  final CreateFolderUsecase _createFolder;

  FileManagerViewModel()
      : _getFolders = getIt<GetFoldersUsecase>(),
        _createFolder = getIt<CreateFolderUsecase>(),
        super(const FileManagerState()) {
    refresh('/');
  }

  Future<void> refresh(String path) async {
    state = state.copyWith(loading: true, error: null, currentPath: path, searchQuery: null);
    try {
      final folders = await _getFolders(path);
      state = state.copyWith(folders: folders, allFolders: folders, loading: false);
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
    List<FTPFolder> result = List.from(state.allFolders);
    
    // Apply search filter
    if (state.searchQuery != null && state.searchQuery!.isNotEmpty) {
      result = result.where((folder) => 
          folder.name.toLowerCase().contains(state.searchQuery!.toLowerCase())).toList();
    }
    
    // Apply sorting
    switch (state.sortOption) {
      case FolderSortOption.name:
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case FolderSortOption.nameReverse:
        result.sort((a, b) => b.name.compareTo(a.name));
        break;
    }
    
    state = state.copyWith(folders: result);
  }

  Future<void> createFolderInCurrent(String name) async {
    final newPath = '${state.currentPath.endsWith('/') ? state.currentPath : state.currentPath + '/'}$name';
    await _createFolder(newPath);
    await refresh(state.currentPath);
  }
}


final fileManagerViewModelProvider =
    StateNotifierProvider<FileManagerViewModel, FileManagerState>((ref) => FileManagerViewModel());
