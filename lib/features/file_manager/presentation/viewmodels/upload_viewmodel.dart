import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/upload_progress.dart';
import '../../domain/usecases/upload_file_usecase.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/upload_cancel_token.dart';

class UploadState {
  final bool picking;
  final bool uploading;
  final UploadProgress? progress;
  final String? error;
  final double? uploadSpeed; // in KB/s

  const UploadState({
    this.picking = false,
    this.uploading = false,
    this.progress,
    this.error,
    this.uploadSpeed,
  });

  UploadState copyWith({
    bool? picking,
    bool? uploading,
    UploadProgress? progress,
    String? error,
    double? uploadSpeed,
  }) =>
      UploadState(
        picking: picking ?? this.picking,
        uploading: uploading ?? this.uploading,
        progress: progress ?? this.progress,
        error: error,
        uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      );
}

class UploadViewModel extends StateNotifier<UploadState> {
  final UploadFileUsecase _uploadFile;
  UploadCancelToken? _cancelToken;

  UploadViewModel()
      : _uploadFile = getIt<UploadFileUsecase>(),
        super(const UploadState());

  void cancelUpload() {
    _cancelToken?.cancel();
  }

  Future<void> upload(String localPath, String remotePath) async {
    _cancelToken = UploadCancelToken();
    state = state.copyWith(uploading: true, error: null, progress: null);

    final stopwatch = Stopwatch()..start();
    int lastBytes = 0;

    try {
      final stream = _uploadFile(localPath, remotePath, cancelToken: _cancelToken);
      await for (final p in stream) {
        if (_cancelToken?.isCancelled == true) {
          state = state.copyWith(uploading: false, progress: p.copyWith(status: UploadStatus.cancelled));
          return;
        }

        final elapsed = stopwatch.elapsedMilliseconds;
        if (elapsed > 0) {
          final bytesSinceLast = p.uploadedBytes - lastBytes;
          final speed = (bytesSinceLast / elapsed) * 1000 / 1024; // KB/s
          state = state.copyWith(progress: p, uploadSpeed: speed);
          lastBytes = p.uploadedBytes;
          stopwatch.reset();
        } else {
          state = state.copyWith(progress: p);
        }
      }
      state = state.copyWith(uploading: false);
    } catch (e) {
      state = state.copyWith(uploading: false, error: e.toString());
    }
  }
}

final uploadViewModelProvider =
    StateNotifierProvider<UploadViewModel, UploadState>(
        (ref) => UploadViewModel());
