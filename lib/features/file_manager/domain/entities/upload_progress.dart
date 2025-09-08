import 'package:equatable/equatable.dart';
import 'package:file_upload/core/di/injection.dart';
import 'package:file_upload/features/file_manager/domain/usecases/generate_link_usecase.dart';

enum UploadStatus { pending, uploading, completed, failed, cancelled }

class UploadProgress extends Equatable {
  final String fileName;
  final String filePath;
  final String targetFolderPath;
  final int totalBytes;
  final int uploadedBytes;
  final UploadStatus status;
  final String? errorMessage;
  final DateTime startTime;
  final DateTime? endTime;

  UploadProgress({
    required this.fileName,
    required this.filePath,
    required this.targetFolderPath,
    required this.totalBytes,
    this.uploadedBytes = 0,
    this.status = UploadStatus.pending,
    this.errorMessage,
    required this.startTime,
    this.endTime,
  });

  UploadProgress copyWith({
    String? fileName,
    String? filePath,
    String? targetFolderPath,
    int? totalBytes,
    int? uploadedBytes,
    UploadStatus? status,
    String? errorMessage,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return UploadProgress(
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      targetFolderPath: targetFolderPath ?? this.targetFolderPath,
      totalBytes: totalBytes ?? this.totalBytes,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  double get progressPercentage {
    if (totalBytes == 0) return 0.0;
    return (uploadedBytes / totalBytes) * 100;
  }

  bool get isCompleted => status == UploadStatus.completed;
  bool get isFailed => status == UploadStatus.failed;
  bool get isUploading => status == UploadStatus.uploading;
  bool get isPending => status == UploadStatus.pending;
  bool get isCancelled => status == UploadStatus.cancelled;

  Duration? get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return null;
  }

  // String get targetUrl {
  //   final cleanFolderPath = targetFolderPath.isEmpty
  //       ? ''
  //       : '$targetFolderPath/';
  //   return 'https://project.ibartstech.com/$cleanFolderPath$fileName';
  // }
  final generateLinkUsecase = getIt<GenerateLinkUsecase>();

  Future<String> get url async =>
      generateLinkUsecase.fileUrl(targetFolderPath, fileName);

  @override
  List<Object?> get props => [
        fileName,
        filePath,
        targetFolderPath,
        totalBytes,
        uploadedBytes,
        status,
        errorMessage,
        startTime,
        endTime,
      ];
}
