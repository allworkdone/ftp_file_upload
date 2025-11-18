import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';
import '../viewmodels/file_viewer_viewmodel.dart';

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
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  @override
  void dispose() {
    super.dispose();
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

  bool get _isPdfFile {
    final ext = widget.fileName.split('.').last.toLowerCase();
    return ext == 'pdf';
  }

  void _handleZoom(double scaleDelta) {
    final newZoom = _pdfViewerController.zoomLevel + scaleDelta;
    _pdfViewerController.zoomLevel = newZoom.clamp(0.25, 10.0);
  }

  @override
  Widget build(BuildContext context) {
    final folderPath =
        widget.filePath.substring(0, widget.filePath.lastIndexOf('/'));
    final args =
        FileViewerArgs(folderPath: folderPath, fileName: widget.fileName);
    final state = ref.watch(fileViewerViewModelProvider(args));

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
      body: _buildBody(state),
    );
  }

  Widget _buildBody(FileViewerState state) {
    if (state.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryLight,
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            state.error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (state.fileUrl == null) {
      return const Center(
          child: Text('Could not generate file URL',
              style: TextStyle(color: Colors.white)));
    }

    if (_isImageFile) {
      return Container(
        color: Colors.black,
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: CachedNetworkImage(
            imageUrl: state.fileUrl!,
            placeholder: (context, url) => Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight),
            ),
            errorWidget: (context, url, error) =>
                const Icon(Icons.error, color: Colors.red),
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            memCacheWidth: 2048, // Request higher resolution from cache
          ),
        ),
      );
    }

    if (_isVideoFile) {
      final videoState = ref.watch(videoPlayerProvider(state.fileUrl!));

      return videoState.when(
        data: (controller) => Center(
          child: Chewie(controller: controller),
        ),
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.primaryLight),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Failed to initialize video player: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_isPdfFile) {
      return Stack(
        children: [
          Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                final isCtrlPressed = HardwareKeyboard.instance
                        .isLogicalKeyPressed(LogicalKeyboardKey.controlLeft) ||
                    HardwareKeyboard.instance
                        .isLogicalKeyPressed(LogicalKeyboardKey.controlRight);
                if (isCtrlPressed) {
                  final delta = event.scrollDelta.dy > 0 ? -0.1 : 0.1;
                  _handleZoom(delta);
                }
              }
            },
            onPointerPanZoomUpdate: (event) {
              // Handle trackpad pinch zoom
              if (event.scale != 1.0) {
                final delta = (event.scale - 1.0);
                _handleZoom(delta);
              }
            },
            child: SfPdfViewerTheme(
              data: SfPdfViewerThemeData(
                backgroundColor: Colors.transparent,
                progressBarColor: AppColors.primaryLight,
              ),
              child: SfPdfViewer.network(
                state.fileUrl!,
                controller: _pdfViewerController,
                key: _pdfViewerKey,
                enableDoubleTapZooming: true,
                enableTextSelection: true,
                canShowScrollHead: true,
                canShowScrollStatus: true,
                pageLayoutMode: PdfPageLayoutMode.continuous,
                maxZoomLevel: 10.0,
                onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                  ref
                      .read(fileViewerViewModelProvider(FileViewerArgs(
                              folderPath: widget.filePath.substring(
                                  0, widget.filePath.lastIndexOf('/')),
                              fileName: widget.fileName))
                          .notifier)
                      .setTotalPages(details.document.pages.count);
                },
                onPageChanged: (PdfPageChangedDetails details) {
                  ref
                      .read(fileViewerViewModelProvider(FileViewerArgs(
                              folderPath: widget.filePath.substring(
                                  0, widget.filePath.lastIndexOf('/')),
                              fileName: widget.fileName))
                          .notifier)
                      .setCurrentPage(details.newPageNumber);
                },
                onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                  // Error handling can be improved by updating state via VM if needed
                },
              ),
            ),
          ),
          if (state.totalPages > 0)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon:
                            const Icon(Icons.chevron_left, color: Colors.white),
                        onPressed: state.currentPage > 1
                            ? () {
                                _pdfViewerController.previousPage();
                              }
                            : null,
                      ),
                      Text(
                        'Page ${state.currentPage} of ${state.totalPages}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right,
                            color: Colors.white),
                        onPressed: state.currentPage < state.totalPages
                            ? () {
                                _pdfViewerController.nextPage();
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (_isTextFile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          state.textContent ?? '',
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
