import 'dart:io';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:path/path.dart' as path;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../file_manager/domain/entities/ftp_folder.dart';
import '../../../file_manager/domain/entities/ftp_file.dart';
import '../../../file_manager/domain/usecases/get_folders_usecase.dart';
import '../../../file_manager/domain/usecases/get_files_usecase.dart';
import '../../../file_manager/domain/usecases/delete_file_usecase.dart';
import '../../../file_manager/domain/usecases/delete_folder_usecase.dart';
import '../../../../core/di/injection.dart';
import '../../../../app/router/route_names.dart';
import 'package:go_router/go_router.dart';

class FolderBrowserScreen extends StatefulWidget {
  final String folderPath;
  const FolderBrowserScreen({super.key, required this.folderPath});

  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  bool _loading = true;
  List<FTPFolder> _folders = const [];
  List<FTPFile> _files = const [];
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final folders = await getIt<GetFoldersUsecase>()(widget.folderPath);
      final files = await getIt<GetFilesUsecase>()(widget.folderPath);
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _files = files;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteFolder(FTPFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
            'Are you sure you want to delete "${folder.name}"?\n\nThis action cannot be undone and will delete all contents.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await getIt<DeleteFolderUsecase>()(folder.fullPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Folder "${folder.name}" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _load(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete folder: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteFile(FTPFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text(
            'Are you sure you want to delete "${file.name}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await getIt<DeleteFileUsecase>()(file.fullPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File "${file.name}" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _load(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete file: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _downloadFile(FTPFile file) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 12),
                Text('Downloading "${file.name}"...'),
              ],
            ),
          ),
        );
      }

      final dio = Dio();
      final fileUrl = 'https://project.ibartstech.com${file.fullPath}';

      // Download as bytes first
      final response = await dio.get(
        fileUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final bytes = response.data as List<int>;

        // Use FileSaver to save the file
        final result = await FileSaver.instance.saveFile(
          name: file.name,
          bytes: Uint8List.fromList(bytes),
          fileExtension: file.extension ?? '',
          mimeType: _getMimeType(file.extension),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File downloaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  MimeType _getMimeType(String? extension) {
    if (extension == null) return MimeType.other;

    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return MimeType.jpeg;
      case 'png':
        return MimeType.png;
      case 'gif':
        return MimeType.gif;
      case 'pdf':
        return MimeType.pdf;
      case 'doc':
      case 'docx':
        return MimeType.openDocText;
      case 'xls':
      case 'xlsx':
        return MimeType.openDocSheets;
      case 'zip':
        return MimeType.zip;
      case 'mp3':
        return MimeType.mp3;
      case 'mp4':
        return MimeType.mp4Video;
      default:
        return MimeType.other;
    }
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open URL in browser'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Folder: ${widget.folderPath}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_folders.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('Folders',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ..._folders.map((f) => ListTile(
                        leading: const Icon(Icons.folder, color: Colors.amber),
                        title: Text(f.name),
                        subtitle: Text(
                            '${f.totalFiles} files • ${f.totalSubFolders} folders'),
                        onTap: () => context
                            .push(RouteNames.folderBrowserPath(f.fullPath)),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'delete':
                                await _deleteFolder(f);
                                break;
                              case 'open':
                                await _openInBrowser(
                                    'https://project.ibartstech.com${f.fullPath}');
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'open',
                              child: Row(
                                children: [
                                  Icon(Icons.open_in_browser),
                                  SizedBox(width: 8),
                                  Text('Open in browser'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (_files.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('Files',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ..._files.map((fi) => ListTile(
                        leading: Icon(
                          _getFileIcon(fi.extension),
                          color: _getFileIconColor(fi.extension),
                        ),
                        title: Text(fi.name),
                        subtitle:
                            Text('${_formatFileSize(fi.size)} • ${fi.path}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'download':
                                await _downloadFile(fi);
                                break;
                              case 'delete':
                                await _deleteFile(fi);
                                break;
                              case 'open':
                                await _openInBrowser(
                                    'https://project.ibartstech.com${fi.fullPath}');
                                break;
                              case 'copy_link':
                                // You can implement clipboard functionality here
                                final url =
                                    'https://project.ibartstech.com${fi.fullPath}';
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Link copied: $url'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'download',
                              child: Row(
                                children: [
                                  Icon(Icons.download),
                                  SizedBox(width: 8),
                                  Text('Download'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'open',
                              child: Row(
                                children: [
                                  Icon(Icons.open_in_browser),
                                  SizedBox(width: 8),
                                  Text('Open in browser'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'copy_link',
                              child: Row(
                                children: [
                                  Icon(Icons.link),
                                  SizedBox(width: 8),
                                  Text('Copy link'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (_folders.isEmpty && _files.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.folder_open,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Folder is empty'),
                            SizedBox(height: 4),
                            Text('Upload files or create subfolders'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.go(RouteNames.uploadPath(folderPath: widget.folderPath)),
        child: const Icon(Icons.upload),
        tooltip: 'Upload to this folder',
      ),
    );
  }

  IconData _getFileIcon(String? extension) {
    if (extension == null) return Icons.insert_drive_file;

    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
      case 'flv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return Icons.audio_file;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String? extension) {
    if (extension == null) return Colors.grey;

    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Colors.green;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
      case 'flv':
        return Colors.red;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return Colors.purple;
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.orange;
      case 'txt':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
