import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/upload_progress.dart';
import '../../domain/usecases/upload_file_usecase.dart';
import '../../../../core/di/injection.dart';

class UploadState {
  final bool picking;
  final bool uploading;
  final UploadProgress? progress;
  final String? error;

  const UploadState({
    this.picking = false,
    this.uploading = false,
    this.progress,
    this.error,
  });

  UploadState copyWith({
    bool? picking,
    bool? uploading,
    UploadProgress? progress,
    String? error,
  }) => UploadState(
        picking: picking ?? this.picking,
        uploading: uploading ?? this.uploading,
        progress: progress ?? this.progress,
        error: error,
      );
}

class UploadViewModel extends StateNotifier<UploadState> {
  final UploadFileUsecase _uploadFile;
  UploadViewModel() : _uploadFile = getIt<UploadFileUsecase>(), super(const UploadState());

  Future<void> upload(String localPath, String remotePath) async {
    state = state.copyWith(uploading: true, error: null, progress: null);
    try {
      final stream = _uploadFile(localPath, remotePath);
      await for (final p in stream) {
        state = state.copyWith(progress: p);
      }
      state = state.copyWith(uploading: false);
    } catch (e) {
      state = state.copyWith(uploading: false, error: e.toString());
    }
  }
}

final uploadViewModelProvider = StateNotifierProvider<UploadViewModel, UploadState>((ref) => UploadViewModel());
