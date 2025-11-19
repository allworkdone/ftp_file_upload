import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:archive/archive_io.dart';

import '../../domain/usecases/create_folder_usecase.dart';
import '../../domain/usecases/get_folders_usecase.dart';
import '../../domain/usecases/generate_link_usecase.dart';
import '../../domain/entities/ftp_folder.dart';
import '../../presentation/viewmodels/upload_viewmodel.dart';
import '../../../../core/di/injection.dart';
import 'folder_picker_dialog.dart';
import '../../../../app/theme/app_colors.dart'; // Import your purple theme
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_names.dart';

// Data structure for isolate communication
class _ZipData {
  final String directoryPath;
  final String outputPath;

  _ZipData(this.directoryPath, this.outputPath);
}

// Data class for managing bulk upload items
class BulkUploadItem {
  final PlatformFile file;
  String customName;
  bool isSelected;

  BulkUploadItem(this.file, {String? customName, this.isSelected = true})
      : customName = customName ?? file.name;
}

class FileUploadWidget extends ConsumerStatefulWidget {
  final String folderPath;
  final ValueChanged<String>? onFolderChanged;
  final List<XFile>? droppedFiles;

  const FileUploadWidget({
    super.key,
    required this.folderPath,
    this.onFolderChanged,
    this.droppedFiles,
  });

  @override
  ConsumerState<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends ConsumerState<FileUploadWidget> {
  List<BulkUploadItem> _bulkUploadItems = [];
  // Track which items are in edit mode
  Set<int> _editModeIndices = {};
  late final TextEditingController _folderCtrl;
  final TextEditingController _fileNameCtrl = TextEditingController();
  String? _link, _error;
  bool _loadingFolders = false,
      _isDragging = false,
      _isProcessingBundle = false;
  List<FTPFolder> _folders = const [];
  int _chunkSizeMB = 4;
  final FocusNode _folderFocus = FocusNode();
  final FocusNode _fileNameFocus = FocusNode();
  bool _isBulkUpload = false;
  bool _isUploadInProgress = false;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _folderCtrl = TextEditingController(
        text: widget.folderPath.isEmpty ? '/' : widget.folderPath);
    _loadFolders(_folderCtrl.text);

    // Process dropped files if any were passed
    if (widget.droppedFiles != null && widget.droppedFiles!.isNotEmpty) {
      _handleDroppedFiles(widget.droppedFiles!);
    }
  }

  @override
  void didUpdateWidget(covariant FileUploadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderPath != widget.folderPath)
      _folderCtrl.text = widget.folderPath;
  }

  @override
  void dispose() {
    _folderCtrl.dispose();
    _fileNameCtrl.dispose();
    _folderFocus.dispose();
    _fileNameFocus.dispose();
    super.dispose();
  }

  // Neon glow effect for focused fields
  BoxDecoration _buildNeonGlow(bool hasFocus) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: hasFocus
          ? [
              BoxShadow(
                color: AppColors.primaryLight.withOpacity(0.8),
                blurRadius: 15,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppColors.primary.withOpacity(0.6),
                blurRadius: 25,
                spreadRadius: 1,
              ),
            ]
          : null,
    );
  }

  List<DropdownMenuItem<String>> _buildFolderItems() {
    final seen = <String>{};
    final items = <DropdownMenuItem<String>>[];
    void add(String v) {
      final val = v.isEmpty ? '/' : v;
      if (seen.add(val))
        items.add(DropdownMenuItem(
            value: val,
            child: Text(val, style: const TextStyle(color: Colors.white))));
    }

    if (_folderCtrl.text.isNotEmpty) add(_folderCtrl.text);
    for (final f in _folders) add(f.fullPath);
    return items;
  }

  String? _currentFolderValue(List<DropdownMenuItem<String>> items) {
    final v = _folderCtrl.text.trim();
    return v.isEmpty ? null : (items.any((i) => i.value == v) ? v : null);
  }

  Future<void> _loadFolders(String base) async {
    setState(() => _loadingFolders = true);
    try {
      _folders = await getIt<GetFoldersUsecase>()(base.isEmpty ? '/' : base);
    } catch (_) {
      _folders = const [];
    } finally {
      if (mounted) setState(() => _loadingFolders = false);
    }
  }

  String _parentOf(String p) {
    if (p.isEmpty || p == '/') return '/';
    final s = p.endsWith('/') ? p.substring(0, p.length - 1) : p;
    final i = s.lastIndexOf('/');
    return i <= 0 ? '/' : s.substring(0, i);
  }

  // Isolate function to create zip file
  static void _createZipInIsolate(_ZipData data) {
    final directoryPath = data.directoryPath;
    final outputPath = data.outputPath;

    try {
      print('Starting zip creation for directory: $directoryPath');
      print('Output path: $outputPath');

      final dirName = directoryPath.split('/').last;
      final zipFile = File(outputPath);
      final archive = Archive();
      final directory = Directory(directoryPath);

      print('Processing directory contents');
      // Process directory contents
      directory.listSync(recursive: true).forEach((entity) {
        try {
          if (entity is File) {
            final relativePath =
                entity.path.substring(directoryPath.length + 1);
            print('Adding file: $relativePath');
            final fileBytes = entity.readAsBytesSync();
            archive.addFile(
                ArchiveFile(relativePath, fileBytes.length, fileBytes));
          } else if (entity is Directory) {
            final relativePath =
                entity.path.substring(directoryPath.length + 1) + '/';
            print('Adding directory: $relativePath');
            archive.addFile(ArchiveFile(relativePath, 0, []));
          }
        } catch (e) {
          print('Failed to add ${entity.path}: $e');
        }
      });

      print('Encoding zip archive');
      final zipData = ZipEncoder().encode(archive);
      if (zipData != null) {
        print('Writing zip data to file');
        zipFile.writeAsBytesSync(zipData);
        print('Zip file written successfully');
      } else {
        print('Failed to encode zip archive');
        throw Exception('Failed to encode zip archive');
      }
    } catch (e, stackTrace) {
      print('Error creating zip: $e');
      print('Stack trace: $stackTrace');
      // Re-throw the exception so it can be caught by the caller
      throw Exception('Error creating zip: $e');
    }
  }

  Future<PlatformFile> _createZipFromDirectory(String directoryPath) async {
    setState(() => _isProcessingBundle = true);
    try {
      print('Starting zip creation for directory: $directoryPath');
      final dirName = directoryPath.split('/').last;
      // Use a simpler output path without special characters
      final sanitizedDirName =
          dirName.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
      final outputPath = '${Directory.systemTemp.path}/$sanitizedDirName.zip';
      print('Output path: $outputPath');

      // Create zip data for isolate
      final zipData = _ZipData(directoryPath, outputPath);

      // Create and run isolate with a simpler approach
      print('Creating isolate for zip creation');
      // Use compute instead of Isolate.run for better compatibility
      await compute(_createZipInIsolate, zipData);
      print('Isolate completed');

      // Check if file was created successfully
      final zipFile = File(outputPath);
      print('Checking if zip file exists: ${await zipFile.exists()}');
      if (await zipFile.exists()) {
        final size = await zipFile.length();
        print('Zip file size: $size');
        return PlatformFile(
            name: '$sanitizedDirName.zip', size: size, path: zipFile.path);
      } else {
        print('Zip file does not exist at: $outputPath');
        throw Exception('Failed to create zip archive');
      }
    } catch (e, stackTrace) {
      print('Error creating zip from directory: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to create zip archive: $e');
    } finally {
      setState(() => _isProcessingBundle = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      setState(() => _error = null);
      final result = await FilePicker.platform.pickFiles(
          allowMultiple: true, // Allow multiple files for bulk upload
          type: FileType.any,
          withData: Platform.isMacOS,
          lockParentWindow: Platform.isMacOS);

      if (result?.files.isNotEmpty == true) {
        for (PlatformFile file in result!.files) {
          _bulkUploadItems.add(BulkUploadItem(file));
        }
        _showSnackBar('${result.files.length} file(s) selected', Colors.green);
        setState(() {
          _isBulkUpload = true;
        });
      }
    } catch (e) {
      _showError('Failed to select file: $e');
    }
  }

  Future<void> _pickDirectory() async {
    try {
      setState(() => _error = null);
      final directoryPath = await FilePicker.platform.getDirectoryPath();
      if (directoryPath != null) {
        final zipFile = await _createZipFromDirectory(directoryPath);
        _bulkUploadItems.add(BulkUploadItem(zipFile));
        _showSnackBar(
            'Directory converted to zip: ${zipFile.name}', Colors.green);
        setState(() {
          _isBulkUpload = true;
        });
      }
    } catch (e) {
      _showError('Failed to select directory: $e');
    }
  }

  // Public method to handle dropped files from parent widget
  void handleDroppedFiles(List<XFile> files) {
    _handleDroppedFiles(files);
  }

  void _handleDroppedFiles(List<XFile> files) async {
    setState(() => _isDragging = false);
    if (files.isEmpty) return;

    try {
      print('Processing ${files.length} dropped files');
      for (XFile xFile in files) {
        print('Processing file: ${xFile.path}');
        final stat = await FileStat.stat(xFile.path);
        print('File type: ${stat.type}');

        if (stat.type == FileSystemEntityType.directory) {
          print('Processing directory: ${xFile.path}');
          final zipFile = await _createZipFromDirectory(xFile.path);
          _bulkUploadItems.add(BulkUploadItem(zipFile));
          _showSnackBar(
              'Directory converted to zip: ${zipFile.name}', Colors.green);
        } else {
          print('Processing file: ${xFile.path}');
          final fileSize = await File(xFile.path).length();
          final platformFile =
              PlatformFile(name: xFile.name, size: fileSize, path: xFile.path);
          _bulkUploadItems.add(BulkUploadItem(platformFile));
          _showSnackBar('File added: ${platformFile.name}', Colors.green);
        }
      }
      setState(() {
        _isBulkUpload = true;
      });
      print('Finished processing dropped files');
    } catch (e, stackTrace) {
      print('Error processing dropped files: $e');
      print('Stack trace: $stackTrace');
      _showError('Failed to process dropped file: $e');
    }
  }

  void _showError(String message) => _showSnackBar(message, Colors.red);

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior
            .floating, // Changed back to floating to allow margin
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  void _removeSelectedFile() {
    setState(() {
      _bulkUploadItems.clear();
      _fileNameCtrl.clear();
      _link = null;
      _error = null;
      _isBulkUpload = false;
    });
    _showSnackBar('All selected files removed', Colors.orange);
  }

  void _removeBulkItem(int index) {
    setState(() {
      _bulkUploadItems.removeAt(index);
      if (_bulkUploadItems.isEmpty) {
        _isBulkUpload = false;
      }
    });
    _showSnackBar('File removed from selection', Colors.orange);
  }

  Future<void> _renameAllFiles() async {
    if (_bulkUploadItems.isEmpty) return;

    final controller = TextEditingController();
    String pattern = '';

    // Default pattern based on first file
    if (_bulkUploadItems.isNotEmpty) {
      final firstFile = _bulkUploadItems.first.file;
      final extension = firstFile.extension?.isNotEmpty == true
          ? '.${firstFile.extension}'
          : '';
      pattern = 'file_{{index}}$extension';
    }

    controller.text = pattern;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title: const Text('Rename All Files',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Rename pattern',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText:
                    'Use {{index}} for numbering (e.g., my_file_{{index}}.ext)',
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: AppColors.primaryLight.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: AppColors.primaryLight.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primaryLight, width: 2),
                ),
                filled: true,
                fillColor: AppColors.darkSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Examples:\n- "file_{{index}}" becomes file_1, file_2, etc.\n- "photo_{{index}}.jpg" becomes photo_1.jpg, photo_2.jpg, etc.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        for (int i = 0; i < _bulkUploadItems.length; i++) {
          String newName = result.replaceAll('{{index}}', (i + 1).toString());
          // Ensure the extension is preserved
          final originalExtension = _bulkUploadItems[i].file.extension;
          if (originalExtension != null &&
              originalExtension.isNotEmpty &&
              !newName.endsWith('.$originalExtension')) {
            newName = '$newName.$originalExtension';
          }
          _bulkUploadItems[i].customName = newName;
        }
      });
      _showSnackBar('All files renamed using pattern: $result', Colors.green);
    }
  }

  Future<void> _createFolder() async {
    final nameCtrl = TextEditingController();
    final created = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title:
            const Text('Create Folder', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Folder name',
            labelStyle: const TextStyle(color: Colors.white70),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.primaryLight.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.primaryLight.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primaryLight, width: 2),
            ),
            filled: true,
            fillColor: AppColors.darkSurface.withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created?.isNotEmpty == true) {
      final base = _folderCtrl.text.trim();
      final newPath = ('${base.endsWith('/') ? base : '$base/'}$created')
          .replaceAll(RegExp(r"/+"), '/');
      await getIt<CreateFolderUsecase>()(newPath);
      _folderCtrl.text = newPath;
      _showSnackBar('Folder created: $newPath', Colors.green);
    }
  }

  // Store generated links for each file after upload
  List<Map<String, String>> _generatedLinks = [];

  bool _isFileSupported(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    final supportedExtensions = [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'mp4',
      'mov',
      'avi',
      'mkv',
      'webm',
      'txt',
      'json',
      'xml',
      'md',
      'html',
      'css',
      'js',
      'dart',
      'dart',
      'yaml',
      'log',
      'pdf'
    ];
    return supportedExtensions.contains(ext);
  }

  Future<void> _upload() async {
    if (_bulkUploadItems.isEmpty) return;

    setState(() {
      _generatedLinks.clear(); // Clear previous links
      _error = null;
      _isUploadInProgress = true;
      _isCancelled = false;
    });

    final folder =
        _folderCtrl.text.trim().isEmpty ? '/' : _folderCtrl.text.trim();

    try {
      // Upload each selected file
      for (var item in _bulkUploadItems) {
        if (_isCancelled) break; // Check if user cancelled upload

        final file = item.file;
        final fileName = item.customName;
        final remotePath =
            ('${folder.endsWith('/') ? folder : '$folder/'}$fileName')
                .replaceAll(RegExp(r"/+"), '/');

        String? uploadPath = file.path;

        if ((uploadPath == null || !await File(uploadPath).exists()) &&
            file.bytes != null) {
          final tempFile = File('${Directory.systemTemp.path}/${file.name}');
          await tempFile.writeAsBytes(file.bytes!);
          uploadPath = tempFile.path;
        }

        if (uploadPath == null || !await File(uploadPath).exists()) {
          throw Exception('No valid file available for upload');
        }

        await ref
            .read(uploadViewModelProvider.notifier)
            .upload(uploadPath, remotePath);

        final state = ref.read(uploadViewModelProvider);
        if (state.error != null) {
          setState(() => _error = state.error);
          break; // Stop uploading if there's an error
        }

        // Generate link for this specific file after successful upload
        final link = getIt<GenerateLinkUsecase>()
            .fileUrl(folder.replaceFirst(RegExp('^/'), ''), fileName);
        final generatedLink = await link;
        _generatedLinks.add(
            {'fileName': fileName, 'link': generatedLink, 'path': remotePath});
      }

      if (!_isCancelled) {
        final fileCount = _bulkUploadItems.length;
        // Clear the selected files after upload completion
        setState(() {
          _bulkUploadItems.clear();
          _isBulkUpload = false;
          _isUploadInProgress = false;
        });

        if (fileCount > 0) {
          _showSnackBar(
              'Upload completed for $fileCount file(s)', Colors.green);
        } else {
          _showSnackBar(
              'Upload completed but no files were selected', Colors.orange);
        }
      } else {
        // Clear the selected files after upload cancellation
        setState(() {
          _bulkUploadItems.clear();
          _isBulkUpload = false;
          _isUploadInProgress = false;
        });
        _showSnackBar('Upload cancelled by user', Colors.orange);
      }
    } catch (e) {
      setState(() {
        _isUploadInProgress = false;
        _error = e.toString();
      });
      _showError('Upload failed: $e');
    }
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else if (bytesPerSecond < 1024 * 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
    }
  }

  Widget _buildDropArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border.all(
          color: _isDragging
              ? AppColors.primaryLight
              : AppColors.primaryLight.withOpacity(0.4),
          width: _isDragging ? 2.5 : 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
        color: _isDragging
            ? AppColors.primaryLight.withOpacity(0.1)
            : AppColors.darkSurface.withOpacity(0.6),
        boxShadow: _isDragging
            ? [
                BoxShadow(
                  color: AppColors.primaryLight.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isProcessingBundle) ...[
            CircularProgressIndicator(
              color: AppColors.primaryLight,
              year2023: false,
            ),
            const SizedBox(height: 16),
            const Text('Converting directory to zip...',
                style: TextStyle(color: Colors.white70)),
          ] else ...[
            Icon(
              _isDragging ? Icons.file_download : Icons.upload_file,
              size: 48,
              color: _isDragging
                  ? AppColors.primaryLight
                  : AppColors.primaryLight.withOpacity(0.8),
            ),
            const SizedBox(height: 16),
            Text(
              _isDragging
                  ? 'Release to add file or directory'
                  : (_bulkUploadItems.isEmpty
                      ? 'Drag & drop files/directories here'
                      : '${_bulkUploadItems.length} file(s) selected'),
              style: TextStyle(
                color: _isDragging ? AppColors.primaryLight : Colors.white70,
                fontWeight: _isDragging ? FontWeight.w600 : FontWeight.normal,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildNeonButton(
                  onPressed: _isProcessingBundle ? null : _pickFile,
                  icon: Icons.insert_drive_file,
                  label: 'Select File',
                ),
                const SizedBox(width: 16),
                _buildNeonButton(
                  onPressed: _isProcessingBundle ? null : _pickDirectory,
                  icon: Icons.folder,
                  label: 'Select Directory',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNeonButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: AppColors.primaryLight.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: AppColors.primaryLight.withOpacity(0.5), width: 1),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upload = ref.watch(uploadViewModelProvider);
    final items = _buildFolderItems();

    return DropTarget(
      onDragDone: (detail) {
        // Handle dropped files on the entire screen
        if (detail.files.isNotEmpty) {
          _handleDroppedFiles(detail.files);
        }
      },
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: _isDragging
              ? const RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [
                    Color(0xFF1A0033), // More transparent version of the color
                    Color(0xFF1A003), // Darker background when dragging
                  ],
                  stops: [0.1, 0.9],
                )
              : const RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [
                    Color(0xFF1A003),
                    AppColors.darkBackground,
                  ],
                  stops: [0.1, 0.9],
                ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Client-side Upload',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: AppColors.primaryLight,
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildDropArea(),
              if (_isBulkUpload && _bulkUploadItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _removeSelectedFile,
                      icon:
                          const Icon(Icons.clear, size: 18, color: Colors.red),
                      label: const Text('Remove all files',
                          style: TextStyle(color: Colors.red)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withOpacity(0.5)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Display bulk upload items with rename and remove functionality
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primaryLight.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkBackground.withOpacity(0.6),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(12)),
                          border: Border(
                            bottom: BorderSide(
                                color: AppColors.primaryLight.withOpacity(0.3)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              'Bulk Upload Files (${_bulkUploadItems.length})',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _bulkUploadItems.length,
                          itemBuilder: (context, index) {
                            final item = _bulkUploadItems[index];
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: item.customName,
                                      enabled: _editModeIndices.contains(index),
                                      onChanged: (value) {
                                        setState(() {
                                          // Preserve the original file extension when renaming
                                          final originalFile =
                                              _bulkUploadItems[index].file;
                                          final originalExtension = originalFile
                                                      .extension?.isNotEmpty ==
                                                  true
                                              ? '.${originalFile.extension}'
                                              : '';

                                          // If the new name doesn't end with the original extension, add it back
                                          if (originalExtension.isNotEmpty &&
                                              !value.endsWith(
                                                  originalExtension)) {
                                            _bulkUploadItems[index].customName =
                                                '$value$originalExtension';
                                          } else {
                                            _bulkUploadItems[index].customName =
                                                value;
                                          }
                                        });
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Filename cannot be empty';
                                        }
                                        // Check for invalid characters in filename
                                        if (value.contains(
                                            RegExp(r'[<>:"/\\|?*]'))) {
                                          return 'Filename contains invalid characters';
                                        }
                                        return null;
                                      },
                                      style: TextStyle(
                                        color: _editModeIndices.contains(index)
                                            ? Colors.white
                                            : Colors.white70,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Rename file',
                                        labelStyle: TextStyle(
                                          color:
                                              _editModeIndices.contains(index)
                                                  ? Colors.white70
                                                  : Colors.white54,
                                        ),
                                        filled: true,
                                        fillColor:
                                            _editModeIndices.contains(index)
                                                ? AppColors.darkBackground
                                                : AppColors.darkBackground
                                                    .withOpacity(0.5),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: AppColors.primaryLight
                                                  .withOpacity(0.3)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: AppColors.primaryLight
                                                  .withOpacity(_editModeIndices
                                                          .contains(index)
                                                      ? 0.3
                                                      : 0.1)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: AppColors.primaryLight,
                                              width: _editModeIndices
                                                      .contains(index)
                                                  ? 2
                                                  : 1),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        if (_editModeIndices.contains(index)) {
                                          _editModeIndices.remove(index);
                                        } else {
                                          _editModeIndices.add(index);
                                        }
                                      });
                                    },
                                    icon: Icon(
                                      _editModeIndices.contains(index)
                                          ? Icons.edit
                                          : Icons.edit_outlined,
                                      color: _editModeIndices.contains(index)
                                          ? AppColors.primaryLight
                                          : Colors.white70,
                                      size: 20,
                                    ),
                                    tooltip: _editModeIndices.contains(index)
                                        ? 'Finish editing'
                                        : 'Edit name',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _removeBulkItem(index),
                                    icon: Icon(Icons.delete,
                                        color: Colors.red[300]),
                                    tooltip: 'Remove file',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Text('Remote Folder',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Focus(
                onFocusChange: (hasFocus) => setState(() {}),
                child: Container(
                  decoration: _buildNeonGlow(_folderFocus.hasFocus),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _currentFolderValue(items),
                          hint: Text(_folderCtrl.text,
                              style: const TextStyle(color: Colors.white70)),
                          isExpanded: true,
                          items: items,
                          dropdownColor: AppColors.darkSurface,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.darkSurface.withOpacity(0.8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color:
                                      AppColors.primaryLight.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color:
                                      AppColors.primaryLight.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: AppColors.primaryLight, width: 2),
                            ),
                          ),
                          onChanged: (v) async {
                            setState(
                                () => _folderCtrl.text = v ?? _folderCtrl.text);
                            widget.onFolderChanged?.call(_folderCtrl.text);
                            await _loadFolders(_folderCtrl.text);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Create folder',
                        onPressed: _createFolder,
                        icon: Icon(Icons.create_new_folder_outlined,
                            color: AppColors.primaryLight),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _loadingFolders
                            ? null
                            : () => _loadFolders(_folderCtrl.text),
                        icon: Icon(Icons.refresh,
                            color: _loadingFolders
                                ? Colors.grey
                                : AppColors.primaryLight),
                      ),
                      IconButton(
                        tooltip: 'Browse…',
                        onPressed: () async {
                          final selected = await showDialog<String>(
                            context: context,
                            builder: (_) => FolderPickerDialog(
                                initialPath: _folderCtrl.text),
                          );
                          if (selected?.isNotEmpty == true) {
                            setState(() => _folderCtrl.text = selected!);
                            widget.onFolderChanged?.call(_folderCtrl.text);
                            await _loadFolders(_folderCtrl.text);
                          }
                        },
                        icon: Icon(Icons.folder_open,
                            color: AppColors.primaryLight),
                      ),
                      IconButton(
                        tooltip: 'Up one level',
                        onPressed: () async {
                          final p = _parentOf(_folderCtrl.text);
                          setState(() => _folderCtrl.text = p);
                          widget.onFolderChanged?.call(_folderCtrl.text);
                          await _loadFolders(_folderCtrl.text);
                        },
                        icon: Icon(Icons.arrow_upward,
                            color: AppColors.primaryLight),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Chunk size',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.darkSurface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primaryLight.withOpacity(0.3)),
                ),
                child: DropdownButtonFormField<int>(
                  value: _chunkSizeMB,
                  dropdownColor: AppColors.darkSurface,
                  style: const TextStyle(color: AppColors.darkSurface),
                  items: const [1, 2, 4, 8, 16, 32]
                      .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text('$e MB',
                              style: TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _chunkSizeMB = v ?? _chunkSizeMB),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: InputBorder.none,
                    fillColor: AppColors.darkBackground,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _buildNeonButton(
                  onPressed: _bulkUploadItems.isEmpty ||
                          upload.uploading ||
                          _isProcessingBundle
                      ? null
                      : _upload,
                  icon: Icons.cloud_upload_outlined,
                  label: _isUploadInProgress
                      ? 'Uploading... (${_bulkUploadItems.length} files)'
                      : 'Execute upload',
                ),
              ),
              if (upload.uploading) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  year2023: false,
                  value: upload.progress?.progressPercentage != null
                      ? upload.progress!.progressPercentage / 100.0
                      : null,
                  backgroundColor: AppColors.darkSurface,
                  color: AppColors.primaryLight,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary, // M3 primary color
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        upload.progress == null
                            ? 'Starting…'
                            : '${upload.progress!.fileName} — ${upload.progress!.progressPercentage.toStringAsFixed(0)}% • ${_formatSpeed(upload.progress!.uploadSpeed)}',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isCancelled = true;
                        });
                        _showSnackBar(
                            'Upload cancelled by user', Colors.orange);
                      },
                      icon: Icon(Icons.cancel, color: Colors.red[300]),
                      tooltip: 'Cancel upload',
                    ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.4)),
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
              ],
              if (_generatedLinks.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Shareable links',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.primaryLight.withOpacity(0.3)),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(), // Prevent conflicts with parent scroll
                    itemCount: _generatedLinks.length,
                    itemBuilder: (context, index) {
                      final linkInfo = _generatedLinks[index];
                      final fileName = linkInfo['fileName'] ?? '';
                      final link = linkInfo['link'] ?? '';
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.darkBackground.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.primaryLight.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  fileName,
                                  style: const TextStyle(
                                    color: AppColors.primaryLight,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 4.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        link,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Copy link',
                                      onPressed: () {
                                        Clipboard.setData(
                                            ClipboardData(text: link));
                                        _showSnackBar(
                                            'Link copied to clipboard',
                                            Colors.green);
                                      },
                                      icon: Icon(Icons.copy,
                                          color: AppColors.primaryLight,
                                          size: 16),
                                    ),
                                    if (_isFileSupported(fileName))
                                      IconButton(
                                        tooltip: 'Open in app',
                                        onPressed: () {
                                          final path = linkInfo['path'];
                                          if (path != null) {
                                            context.push(
                                                RouteNames.fileViewerPath(
                                                    path, fileName));
                                          }
                                        },
                                        icon: Icon(Icons.visibility,
                                            color: AppColors.primaryLight,
                                            size: 16),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
