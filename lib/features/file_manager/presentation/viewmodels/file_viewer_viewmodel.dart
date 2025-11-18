import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../domain/usecases/generate_link_usecase.dart';

class FileViewerState {
  final bool isLoading;
  final String? error;
  final String? fileUrl;
  final String? textContent;
  final int currentPage;
  final int totalPages;

  const FileViewerState({
    this.isLoading = true,
    this.error,
    this.fileUrl,
    this.textContent,
    this.currentPage = 1,
    this.totalPages = 0,
  });

  FileViewerState copyWith({
    bool? isLoading,
    String? error,
    String? fileUrl,
    String? textContent,
    int? currentPage,
    int? totalPages,
  }) {
    return FileViewerState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      fileUrl: fileUrl ?? this.fileUrl,
      textContent: textContent ?? this.textContent,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

class FileViewerArgs {
  final String folderPath;
  final String fileName;

  FileViewerArgs({required this.folderPath, required this.fileName});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileViewerArgs &&
          runtimeType == other.runtimeType &&
          folderPath == other.folderPath &&
          fileName == other.fileName;

  @override
  int get hashCode => folderPath.hashCode ^ fileName.hashCode;
}

class FileViewerViewModel extends StateNotifier<FileViewerState> {
  final String folderPath;
  final String fileName;
  final GenerateLinkUsecase _generateLinkUsecase;

  FileViewerViewModel(this.folderPath, this.fileName)
      : _generateLinkUsecase = getIt<GenerateLinkUsecase>(),
        super(const FileViewerState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final url = await _generateLinkUsecase.fileUrl(folderPath, fileName);

      String? textContent;
      if (_isTextFile) {
        try {
          final response = await Dio().get(url);
          textContent = response.data.toString();
        } catch (e) {
          state = FileViewerState(
            isLoading: false,
            error: 'Failed to load text content: $e',
            fileUrl: url,
          );
          return;
        }
      }

      state = FileViewerState(
        isLoading: false,
        fileUrl: url,
        textContent: textContent,
      );
    } catch (e) {
      state = FileViewerState(isLoading: false, error: e.toString());
    }
  }

  bool get _isTextFile {
    final ext = fileName.split('.').last.toLowerCase();
    return [
      'txt',
      'json',
      'xml',
      'md',
      'html',
      'css',
      'js',
      'dart',
      'yaml',
      'log'
    ].contains(ext);
  }

  void setCurrentPage(int page) {
    state = state.copyWith(currentPage: page);
  }

  void setTotalPages(int total) {
    state = state.copyWith(totalPages: total);
  }
}

final fileViewerViewModelProvider = StateNotifierProvider.family
    .autoDispose<FileViewerViewModel, FileViewerState, FileViewerArgs>(
  (ref, args) => FileViewerViewModel(args.folderPath, args.fileName),
);

// Provider to manage Video Player lifecycle

final videoPlayerProvider = FutureProvider.autoDispose
    .family<ChewieController, String>((ref, url) async {
  final videoPlayerController =
      VideoPlayerController.networkUrl(Uri.parse(url));
  await videoPlayerController.initialize();

  final chewieController = ChewieController(
    videoPlayerController: videoPlayerController,
    autoPlay: true,
    looping: false,
    aspectRatio: videoPlayerController.value.aspectRatio,
    errorBuilder: (context, errorMessage) {
      return Center(
        child: Text(
          errorMessage,
          style: const TextStyle(color: Colors.white),
        ),
      );
    },
  );

  // Dispose controllers when the provider is disposed
  ref.onDispose(() {
    videoPlayerController.dispose();
    chewieController.dispose();
  });

  return chewieController;
});
