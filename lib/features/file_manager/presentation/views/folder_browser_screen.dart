import 'dart:io' show Directory, File, Platform;

import 'package:file_saver/file_saver.dart';
import 'package:file_upload/features/authentication/presentation/viewmodels/auth_viewmodel.dart';
import 'package:file_upload/features/file_manager/data/datasources/ftp_datasource.dart';
import 'package:file_upload/features/file_manager/domain/usecases/generate_link_usecase.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../file_manager/domain/entities/ftp_file.dart';
import '../../../file_manager/domain/entities/ftp_folder.dart';
import '../../../file_manager/domain/usecases/delete_file_usecase.dart';
import '../../../file_manager/domain/usecases/delete_folder_usecase.dart';
import '../../../file_manager/domain/usecases/get_files_usecase.dart';
import '../../../file_manager/domain/usecases/get_folders_usecase.dart';

class FolderBrowserScreen extends ConsumerStatefulWidget {
  final String folderPath;
  const FolderBrowserScreen({super.key, required this.folderPath});

  @override
  ConsumerState<FolderBrowserScreen> createState() =>
      _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends ConsumerState<FolderBrowserScreen> {
  bool _loading = true;
  List<FTPFolder> _folders = const [];
  List<FTPFile> _files = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        getIt<GetFoldersUsecase>()(widget.folderPath),
        getIt<GetFilesUsecase>()(widget.folderPath),
      ]);
      if (mounted) {
        setState(() {
          _folders = results[0] as List<FTPFolder>;
          _files = results[1] as List<FTPFile>;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _deleteItem(String path, String name, bool isFolder) async {
    final confirmed = await _showDeleteDialog(name, isFolder);
    if (confirmed != true) return;

    try {
      if (isFolder) {
        await getIt<DeleteFolderUsecase>()(path);
      } else {
        await getIt<DeleteFileUsecase>()(path);
      }
      _showSnackBar('$name deleted successfully', isSuccess: true);
      _load();
    } catch (e) {
      _showSnackBar('Failed to delete: $e', isSuccess: false);
    }
  }

  Future<bool?> _showDeleteDialog(String name, bool isFolder) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title: Text('Delete ${isFolder ? 'Folder' : 'File'}',
            style: const TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "$name"?\n\nThis action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
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
  }

  Future<void> _downloadFile(FTPFile file) async {
    try {
      // Request storage permission for Android
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status.isDenied) {
          _showSnackBar('Storage permission denied', isSuccess: false);
          return;
        }
      }

      _showSnackBar('Downloading "${file.name}"...', showProgress: true);

      // Get credentials from auth
      final auth = ref.read(authViewModelProvider);
      if (auth.credentials == null) {
        _showSnackBar('No FTP credentials available', isSuccess: false);
        return;
      }

      // Use FTP datasource instead of HTTP
      final ftpDatasource = getIt<FTPDatasource>();

      // Get temporary directory for download
      final tempDir = Directory.systemTemp;
      final tempPath = tempDir.path;

      // Download file via FTP
      final localFilePath = await ftpDatasource.downloadFile(
          auth.credentials!, file.fullPath, tempPath);

      // Read the downloaded file and save it properly
      final downloadedFile = File(localFilePath);
      final bytes = await downloadedFile.readAsBytes();

      // Save to user's downloads/documents
      await FileSaver.instance.saveFile(
        name: file.name,
        bytes: bytes,
        fileExtension: file.extension ?? '',
        mimeType: _getMimeType(file.extension),
      );

      // Clean up temp file
      await downloadedFile.delete();

      _showSnackBar('File downloaded successfully!', isSuccess: true);
    } catch (e) {
      _showSnackBar('Download failed: $e', isSuccess: false);
    }
  }

  Future<void> _copyLink(String path) async {
    final generateLinkUsecase = getIt<GenerateLinkUsecase>();
    final fileName = path.split('/').last;
    final folderPath = path.replaceFirst('/$fileName', '');
    final url = await generateLinkUsecase.fileUrl(folderPath, fileName);

    await Clipboard.setData(ClipboardData(text: url));
    _showSnackBar('Link copied to clipboard', isSuccess: true);
  }

  Future<void> _openInBrowser(String path) async {
    // final url = 'https://project.ibartstech.com$path';
    final generateLinkUsecase = getIt<GenerateLinkUsecase>();
    final String url;

    if (path.contains('.')) {
      // It's a file
      final fileName = path.split('/').last;
      final folderPath = path.replaceFirst('/$fileName', '');
      url = await generateLinkUsecase.fileUrl(folderPath, fileName);
    } else {
      // It's a folder
      url = await generateLinkUsecase.folderUrl(path);
    }

    final uri = Uri.parse(url);

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // For mobile platforms, use external application mode
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // For desktop platforms, check if can launch then launch
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        } else {
          throw Exception('Cannot launch URL');
        }
      }
    } catch (e) {
      _showSnackBar('Could not open URL in browser', isSuccess: false);
    }
  }

  void _showSnackBar(String message,
      {bool isSuccess = true, bool showProgress = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (showProgress)
              CircularProgressIndicator(
                year2023: false,
                color: AppColors.primaryLight,
                backgroundColor: AppColors.darkSurface,
              ),
            if (showProgress) const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  MimeType _getMimeType(String? ext) {
    if (ext == null) return MimeType.other;
    const mimeMap = {
      'jpg': MimeType.jpeg,
      'jpeg': MimeType.jpeg,
      'png': MimeType.png,
      'gif': MimeType.gif,
      'pdf': MimeType.pdf,
      'doc': MimeType.other,
      'docx': MimeType.other,
      'xls': MimeType.other,
      'xlsx': MimeType.other,
      'zip': MimeType.zip,
      'mp3': MimeType.mp3,
      'mp4': MimeType.mp4Video,
    };
    return mimeMap[ext.toLowerCase()] ?? MimeType.other;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, String text,
      {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color ?? AppColors.primaryLight),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color ?? Colors.white)),
        ],
      ),
    );
  }

  Widget _buildFolderTile(FTPFolder folder) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(Icons.folder, color: Colors.amber[300]),
        title: Text(folder.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
            '${folder.totalFiles} files • ${folder.totalSubFolders} folders',
            style: const TextStyle(color: Colors.white70)),
        onTap: () =>
            context.push(RouteNames.folderBrowserPath(folder.fullPath)),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppColors.primaryLight),
          color: AppColors.darkSurface,
          onSelected: (value) async {
            switch (value) {
              case 'open':
                _openInBrowser(folder.fullPath);
                break;
              case 'delete':
                _deleteItem(folder.fullPath, folder.name, true);
                break;
            }
          },
          itemBuilder: (context) => [
            _buildMenuItem('open', Icons.open_in_browser, 'Open in browser'),
            _buildMenuItem('delete', Icons.delete, 'Delete',
                color: Colors.red[300]),
          ],
        ),
      ),
    );
  }

  Widget _buildFileTile(FTPFile file) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(_getFileIcon(file.extension),
            color: _getFileIconColor(file.extension)),
        title: Text(file.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text('${_formatSize(file.size)}',
            style: const TextStyle(color: Colors.white70)),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppColors.primaryLight),
          color: AppColors.darkSurface,
          onSelected: (value) async {
            switch (value) {
              case 'download':
                _downloadFile(file);
                break;
              case 'open':
                _openInBrowser(file.fullPath);
                break;
              case 'copy':
                _copyLink(file.fullPath);
                break;
              case 'delete':
                _deleteItem(file.fullPath, file.name, false);
                break;
            }
          },
          itemBuilder: (context) => [
            _buildMenuItem('download', Icons.download, 'Download'),
            _buildMenuItem('open', Icons.open_in_browser, 'Open in browser'),
            _buildMenuItem('copy', Icons.link, 'Copy link'),
            _buildMenuItem('delete', Icons.delete, 'Delete',
                color: Colors.red[300]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text(widget.folderPath,
            style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.darkSurface,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: AppColors.primaryLight),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              Color(0xFF1A0033),
              AppColors.darkBackground,
            ],
            stops: [0.1, 0.9],
          ),
        ),
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                year2023: false,
                color: AppColors.primaryLight,
                backgroundColor: AppColors.darkSurface,
              ))
            : RefreshIndicator(
                backgroundColor: AppColors.darkSurface,
                color: AppColors.primaryLight,
                onRefresh: _load,
                child: ListView(
                  children: [
                    if (_error != null) _buildErrorCard(),

                    // Current path
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Text(
                        'Path: ${widget.folderPath}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),

                    if (_folders.isNotEmpty) _buildSectionHeader('Folders'),
                    ..._folders.map(_buildFolderTile),
                    if (_files.isNotEmpty) _buildSectionHeader('Files'),
                    ..._files.map(_buildFileTile),
                    if (_folders.isEmpty && _files.isEmpty) _buildEmptyState(),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.go(RouteNames.uploadPath(folderPath: widget.folderPath)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.upload, color: Colors.white),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red[300]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red[300]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(title,
          style: TextStyle(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.bold,
              fontSize: 16)),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Folder is empty',
                style: TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Upload files or create subfolders',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String? ext) {
    if (ext == null) return Icons.insert_drive_file;
    const iconMap = {
      'jpg': Icons.image,
      'jpeg': Icons.image,
      'png': Icons.image,
      'gif': Icons.image,
      'mp4': Icons.video_file,
      'avi': Icons.video_file,
      'mov': Icons.video_file,
      'mp3': Icons.audio_file,
      'wav': Icons.audio_file,
      'flac': Icons.audio_file,
      'pdf': Icons.picture_as_pdf,
      'doc': Icons.description,
      'docx': Icons.description,
      'xls': Icons.table_chart,
      'xlsx': Icons.table_chart,
      'zip': Icons.archive,
      'rar': Icons.archive,
      '7z': Icons.archive,
      'txt': Icons.text_snippet,
    };
    return iconMap[ext.toLowerCase()] ?? Icons.insert_drive_file;
  }

  Color _getFileIconColor(String? ext) {
    if (ext == null) return Colors.grey[400]!;
    const colorMap = {
      'jpg': Colors.green,
      'jpeg': Colors.green,
      'png': Colors.green,
      'gif': Colors.green,
      'mp4': Colors.red,
      'avi': Colors.red,
      'mov': Colors.red,
      'mp3': Colors.purple,
      'wav': Colors.purple,
      'flac': Colors.purple,
      'pdf': Colors.red,
      'doc': Colors.blue,
      'docx': Colors.blue,
      'xls': Colors.green,
      'xlsx': Colors.green,
      'zip': Colors.orange,
      'rar': Colors.orange,
      '7z': Colors.orange,
      'txt': Colors.grey,
    };
    return colorMap[ext.toLowerCase()]?[300] ?? Colors.grey[400]!;
  }
}
