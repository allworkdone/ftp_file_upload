import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';
import 'package:file_upload/core/di/injection.dart';
import 'package:file_upload/features/file_manager/domain/usecases/generate_link_usecase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';

class FileViewerScreen extends ConsumerStatefulWidget {
  final String filePath;
  final String fileName;

  const FileViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  ConsumerState<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends ConsumerState<FileViewerScreen> {
  String? _fileUrl;
  bool _isLoading = true;
  String? _error;
  String? _textContent;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializeFile();
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _initializeFile() async {
    try {
      final generateLinkUsecase = getIt<GenerateLinkUsecase>();
      // filePath is the full path including filename
      // We need to extract the folder path
      final folderPath = widget.filePath.substring(0, widget.filePath.lastIndexOf('/'));
      final url = await generateLinkUsecase.fileUrl(folderPath, widget.fileName);
      
      if (mounted) {
        setState(() {
          _fileUrl = url;
        });
      }

      if (_isTextFile) {
        await _fetchTextContent(url);
      } else if (_isVideoFile) {
        await _initializeVideoPlayer(url);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchTextContent(String url) async {
    try {
      final response = await Dio().get(url);
      if (mounted) {
        setState(() {
          _textContent = response.data.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load text content: $e';
        });
      }
    }
  }

  Future<void> _initializeVideoPlayer(String url) async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoPlayerController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize video player: $e';
        });
      }
    }
  }

  bool get _isImageFile {
    final ext = widget.fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  bool get _isVideoFile {
    final ext = widget.fileName.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
  }

  bool get _isTextFile {
    final ext = widget.fileName.split('.').last.toLowerCase();
    return ['txt', 'json', 'xml', 'md', 'html', 'css', 'js', 'dart', 'yaml', 'log'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: Colors.white,
        title: Text(widget.fileName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryLight,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_fileUrl == null) {
      return const Center(child: Text('Could not generate file URL', style: TextStyle(color: Colors.white)));
    }

    if (_isImageFile) {
      return Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: _fileUrl!,
            placeholder: (context, url) => Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight),
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    if (_isVideoFile) {
      if (_chewieController != null && _videoPlayerController!.value.isInitialized) {
        return Center(
          child: Chewie(controller: _chewieController!),
        );
      } else {
        return Center(
          child: CircularProgressIndicator(color: AppColors.primaryLight),
        );
      }
    }

    if (_isTextFile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _textContent ?? '',
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Preview not available for this file type',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
