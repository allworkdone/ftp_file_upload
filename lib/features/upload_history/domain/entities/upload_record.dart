import 'package:equatable/equatable.dart';

class UploadRecord extends Equatable {
  final String id;
  final String fileName;
  final String originalFilePath;
  final String targetFolderPath;
  final String generatedUrl;
  final int fileSize;
  final DateTime uploadTime;
  final Duration uploadDuration;
  final bool isSuccessful;
  final String? errorMessage;

  const UploadRecord({
    required this.id,
    required this.fileName,
    required this.originalFilePath,
    required this.targetFolderPath,
    required this.generatedUrl,
    required this.fileSize,
    required this.uploadTime,
    required this.uploadDuration,
    this.isSuccessful = true,
    this.errorMessage,
  });

  UploadRecord copyWith({
    String? id,
    String? fileName,
    String? originalFilePath,
    String? targetFolderPath,
    String? generatedUrl,
    int? fileSize,
    DateTime? uploadTime,
    Duration? uploadDuration,
    bool? isSuccessful,
    String? errorMessage,
  }) {
    return UploadRecord(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      originalFilePath: originalFilePath ?? this.originalFilePath,
      targetFolderPath: targetFolderPath ?? this.targetFolderPath,
      generatedUrl: generatedUrl ?? this.generatedUrl,
      fileSize: fileSize ?? this.fileSize,
      uploadTime: uploadTime ?? this.uploadTime,
      uploadDuration: uploadDuration ?? this.uploadDuration,
      isSuccessful: isSuccessful ?? this.isSuccessful,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedDuration {
    final minutes = uploadDuration.inMinutes;
    final seconds = uploadDuration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  @override
  List<Object?> get props => [
    id,
    fileName,
    originalFilePath,
    targetFolderPath,
    generatedUrl,
    fileSize,
    uploadTime,
    uploadDuration,
    isSuccessful,
    errorMessage,
  ];
}
