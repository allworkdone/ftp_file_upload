import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ftp_folder.dart';
import '../../domain/usecases/get_folders_usecase.dart';
import '../../domain/usecases/create_folder_usecase.dart';
import '../../../../core/di/injection.dart';

class FileManagerState {
  final String currentPath;
  final List<FTPFolder> folders;
  final bool loading;
  final String? error;

  const FileManagerState({
    this.currentPath = '/',
    this.folders = const [],
    this.loading = false,
    this.error,
  });

  FileManagerState copyWith({
    String? currentPath,
    List<FTPFolder>? folders,
    bool? loading,
    String? error,
  }) => FileManagerState(
        currentPath: currentPath ?? this.currentPath,
        folders: folders ?? this.folders,
        loading: loading ?? this.loading,
        error: error,
      );
}

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
    state = state.copyWith(loading: true, error: null, currentPath: path);
    try {
      final folders = await _getFolders(path);
      state = state.copyWith(folders: folders, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> createFolderInCurrent(String name) async {
    final newPath = '${state.currentPath.endsWith('/') ? state.currentPath : state.currentPath + '/'}$name';
    await _createFolder(newPath);
    await refresh(state.currentPath);
  }
}

final fileManagerViewModelProvider =
    StateNotifierProvider<FileManagerViewModel, FileManagerState>((ref) => FileManagerViewModel());
