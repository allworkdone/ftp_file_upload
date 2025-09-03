import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:archive/archive_io.dart';

import '../../domain/usecases/create_folder_usecase.dart';
import '../../domain/usecases/get_folders_usecase.dart';
import '../../domain/usecases/generate_link_usecase.dart';
import '../../domain/entities/ftp_folder.dart';
import '../../data/datasources/local_file_datasource.dart';
import '../../presentation/viewmodels/upload_viewmodel.dart';
import '../../../../core/di/injection.dart';
import 'folder_picker_dialog.dart';

class FileUploadWidget extends ConsumerStatefulWidget {
  final String folderPath;
  final ValueChanged<String>? onFolderChanged;
  const FileUploadWidget(
      {super.key, required this.folderPath, this.onFolderChanged});

  @override
  ConsumerState<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends ConsumerState<FileUploadWidget> {
  PlatformFile? _picked;
  late final TextEditingController _folderCtrl;
  final TextEditingController _fileNameCtrl = TextEditingController();
  String? _link;
  String? _error;
  bool _loadingFolders = false;
  List<FTPFolder> _folders = const [];
  int _chunkSizeMB = 4;
  bool _isDragging = false;
  bool _isProcessingBundle = false; // Track bundle processing

  List<DropdownMenuItem<String>> _buildFolderItems() {
    final seen = <String>{};
    final items = <DropdownMenuItem<String>>[];
    void add(String v) {
      final val = v.isEmpty ? '/' : v;
      if (seen.add(val)) {
        items.add(DropdownMenuItem(value: val, child: Text(val)));
      }
    }

    if (_folderCtrl.text.isNotEmpty) add(_folderCtrl.text);
    for (final f in _folders) {
      add(f.fullPath);
    }
    return items;
  }

  String? _currentFolderValue(List<DropdownMenuItem<String>> items) {
    final v = _folderCtrl.text.trim();
    if (v.isEmpty) return null;
    return items.any((i) => i.value == v) ? v : null;
  }

  @override
  void initState() {
    super.initState();
    _folderCtrl = TextEditingController(
        text: widget.folderPath.isEmpty ? '/' : widget.folderPath);
    _loadFolders(_folderCtrl.text);
  }

  @override
  void didUpdateWidget(covariant FileUploadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderPath != widget.folderPath) {
      _folderCtrl.text = widget.folderPath;
    }
  }

  @override
  void dispose() {
    _folderCtrl.dispose();
    _fileNameCtrl.dispose();
    super.dispose();
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

  // Helper method to check if a directory is a valid bundle/package
  bool _isValidBundle(String filePath) {
    final fileName = filePath.split('/').last.toLowerCase();

    const validBundleExtensions = [
      '.xcarchive', // Xcode archive
      '.app', // macOS/iOS application bundle
      '.framework', // Framework bundle
      '.bundle', // Generic bundle
      '.plugin', // Plugin bundle
      '.kext', // Kernel extension
      '.prefPane', // Preference pane
      '.qlgenerator', // Quick Look generator
      '.saver', // Screen saver
      '.service', // Service
      '.workflow', // Automator workflow
      '.photoslibrary', // Photos library
      '.rtfd', // Rich Text Format Directory
      '.key', // Keynote presentation
      '.pages', // Pages document
      '.numbers', // Numbers spreadsheet
      '.sketch', // Sketch design file
    ];

    return validBundleExtensions.any((ext) => fileName.endsWith(ext));
  }

  // Helper method to validate if a file is accessible and uploadable
  Future<bool> _isValidFileOrBundle(String filePath) async {
    try {
      final stat = await FileStat.stat(filePath);

      if (stat.type == FileSystemEntityType.file) {
        // Regular file - check if it exists and is readable
        final file = File(filePath);
        final exists = await file.exists();
        if (exists) {
          try {
            await file.length(); // Test if readable
            return true;
          } catch (e) {
            print('[FileUpload] File not readable: $filePath - $e');
            return false;
          }
        }
        return false;
      } else if (stat.type == FileSystemEntityType.directory) {
        // Directory - check if it's a valid bundle
        if (_isValidBundle(filePath)) {
          final dir = Directory(filePath);
          return await dir.exists();
        }
        return false;
      }

      return false;
    } catch (e) {
      print('[FileUpload] File validation failed for $filePath: $e');
      return false;
    }
  }

  // Create zip archive from bundle
  Future<PlatformFile> _createBundleZip(String bundlePath) async {
    setState(() => _isProcessingBundle = true);

    try {
      print('[FileUpload] Creating zip archive for bundle: $bundlePath');

      final bundleName = bundlePath.split('/').last;
      final zipFileName = '$bundleName.zip';

      // Create temporary zip file
      final tempDir = Directory.systemTemp;
      final zipFile = File('${tempDir.path}/$zipFileName');

      // Create archive
      final archive = Archive();
      final bundleDir = Directory(bundlePath);

      // Add all files from bundle to archive
      await for (final entity in bundleDir.list(recursive: true)) {
        if (entity is File) {
          try {
            final relativePath = entity.path.substring(bundlePath.length + 1);
            final fileBytes = await entity.readAsBytes();
            final archiveFile =
                ArchiveFile(relativePath, fileBytes.length, fileBytes);
            archive.addFile(archiveFile);
            print('[FileUpload] Added to archive: $relativePath');
          } catch (e) {
            print(
                '[FileUpload] Failed to add file to archive: ${entity.path} - $e');
          }
        } else if (entity is Directory) {
          // Add empty directories
          try {
            final relativePath =
                entity.path.substring(bundlePath.length + 1) + '/';
            final archiveFile = ArchiveFile(relativePath, 0, []);
            archive.addFile(archiveFile);
          } catch (e) {
            print(
                '[FileUpload] Failed to add directory to archive: ${entity.path} - $e');
          }
        }
      }

      // Encode and save zip
      final zipData = ZipEncoder().encode(archive);
      if (zipData != null) {
        await zipFile.writeAsBytes(zipData);
        print('[FileUpload] Zip archive created: ${zipFile.path}');

        // Return as PlatformFile
        final fileSize = await zipFile.length();
        return PlatformFile(
          name: zipFileName,
          size: fileSize,
          path: zipFile.path,
        );
      } else {
        throw Exception('Failed to encode zip archive');
      }
    } catch (e) {
      print('[FileUpload] Error creating zip archive: $e');
      throw Exception('Failed to create zip archive: $e');
    } finally {
      setState(() => _isProcessingBundle = false);
    }
  }

  Future<void> _pickFileOrBundle() async {
    print('[FileUpload] Starting file/bundle picker...');

    try {
      // Use directory picker for bundles, file picker for regular files
      final result = await FilePicker.platform.getDirectoryPath();

      if (result != null) {
        print('[FileUpload] Directory selected: $result');

        // Check if it's a valid bundle
        if (_isValidBundle(result)) {
          print('[FileUpload] Valid bundle detected: $result');

          // Create zip archive from bundle
          _picked = await _createBundleZip(result);
          _fileNameCtrl.text = _picked!.name;

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Bundle converted to zip: ${_picked!.name}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          _showError('Selected directory is not a supported bundle type');
          return;
        }
      } else {
        // Try regular file picker
        final fileResult = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.any,
          withData: Platform.isMacOS,
          withReadStream: false,
        );

        if (fileResult != null && fileResult.files.isNotEmpty) {
          final file = fileResult.files.single;
          print('[FileUpload] File picked: ${file.name}');

          _picked = file;
          _fileNameCtrl.text = _picked!.name;
        } else {
          print('[FileUpload] No file or bundle selected');
          return;
        }
      }

      setState(() {});
    } catch (e) {
      print('[FileUpload] Error picking file/bundle: $e');
      _showError('Failed to select file or bundle: $e');
    }
  }

  // Handle dropped files with bundle support
  void _handleDroppedFiles(List<XFile> files) async {
    print('[FileUpload] Handling ${files.length} dropped files');

    setState(() => _isDragging = false);

    if (files.isEmpty) {
      print('[FileUpload] No files in drop');
      return;
    }

    try {
      final xFile = files.first;
      print('[FileUpload] Processing dropped file: ${xFile.name}');
      print('[FileUpload] File path: ${xFile.path}');

      // Check if it's a valid file or bundle
      final isValid = await _isValidFileOrBundle(xFile.path);
      if (!isValid) {
        _showError(
            'Dropped item "${xFile.name}" is not a valid file or supported bundle');
        return;
      }

      // Check if it's a bundle that needs zipping
      final stat = await FileStat.stat(xFile.path);
      if (stat.type == FileSystemEntityType.directory &&
          _isValidBundle(xFile.path)) {
        print('[FileUpload] Bundle detected, creating zip...');
        _picked = await _createBundleZip(xFile.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bundle converted to zip: ${_picked!.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Regular file
        final fileSize = await File(xFile.path).length();
        _picked = PlatformFile(
          name: xFile.name,
          size: fileSize,
          path: xFile.path,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File added: ${_picked!.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      _fileNameCtrl.text = _picked!.name;
      setState(() {});

      print('[FileUpload] Successfully processed: ${_picked!.name}');
    } catch (e) {
      print('[FileUpload] Error processing dropped file: $e');
      _showError('Failed to process dropped file: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _createFolder() async {
    final nameCtrl = TextEditingController();
    final created = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Folder name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (created != null && created.isNotEmpty) {
      final base = _folderCtrl.text.trim();
      final newPath = ('${base.endsWith('/') ? base : base + '/'}$created')
          .replaceAll(RegExp(r"/+"), '/');
      await getIt<CreateFolderUsecase>()(newPath);
      _folderCtrl.text = newPath;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Folder created: $newPath')));
      }
    }
  }

  Future<void> _upload() async {
    setState(() {
      _link = null;
      _error = null;
    });
    final file = _picked;
    if (file == null) return;

    final folder =
        _folderCtrl.text.trim().isEmpty ? '/' : _folderCtrl.text.trim();
    final fileName = _fileNameCtrl.text.trim().isEmpty
        ? file.name
        : _fileNameCtrl.text.trim();
    final remotePath =
        ('${folder.endsWith('/') ? folder : folder + '/'}$fileName')
            .replaceAll(RegExp(r"/+"), '/');

    print('[FileUpload] Starting upload...');
    print('[FileUpload] Local file: ${file.name}');
    print('[FileUpload] Local path: ${file.path}');
    print('[FileUpload] Remote path: $remotePath');

    try {
      String? uploadPath = file.path;

      // If we don't have a valid path but have bytes, create a temporary file
      if ((uploadPath == null || !await File(uploadPath).exists()) &&
          file.bytes != null) {
        print('[FileUpload] Creating temporary file for upload...');
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/${file.name}');
        await tempFile.writeAsBytes(file.bytes!);
        uploadPath = tempFile.path;
        print('[FileUpload] Temporary file created: $uploadPath');
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
        return;
      }

      final link = getIt<GenerateLinkUsecase>()
          .fileUrl(folder.replaceFirst(RegExp('^/'), ''), fileName);
      setState(() => _link = link);

      print('[FileUpload] Upload successful');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload completed: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[FileUpload] Upload failed: $e');
      setState(() => _error = e.toString());
      _showError('Upload failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final upload = ref.watch(uploadViewModelProvider);
    return SingleChildScrollView(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Client-side Upload',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),

        // Enhanced Pick area with drag & drop support
        DropTarget(
          onDragDone: (detail) {
            print('[FileUpload] Drag done with ${detail.files.length} files');
            _handleDroppedFiles(detail.files);
          },
          onDragEntered: (detail) {
            print('[FileUpload] Drag entered');
            setState(() => _isDragging = true);
          },
          onDragExited: (detail) {
            print('[FileUpload] Drag exited');
            setState(() => _isDragging = false);
          },
          child: InkWell(
            onTap: _isProcessingBundle ? null : _pickFileOrBundle,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isDragging
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.primary.withOpacity(0.4),
                  width: _isDragging ? 2.5 : 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
                color: _isDragging
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isProcessingBundle) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text('Converting bundle to zip...'),
                  ] else if (_picked != null &&
                      (_picked!.extension?.toLowerCase().contains('png') ==
                              true ||
                          _picked!.extension?.toLowerCase().contains('jpg') ==
                              true ||
                          _picked!.extension?.toLowerCase().contains('jpeg') ==
                              true ||
                          _picked!.extension?.toLowerCase().contains('webp') ==
                              true ||
                          _picked!.extension?.toLowerCase().contains('gif') ==
                              true))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _picked!.path != null
                          ? Image.file(
                              File(_picked!.path!),
                              height: 120,
                              fit: BoxFit.cover,
                            )
                          : (_picked!.bytes != null
                              ? Image.memory(_picked!.bytes!,
                                  height: 120, fit: BoxFit.cover)
                              : const Icon(Icons.image, size: 40)),
                    )
                  else
                    Icon(
                      _isDragging ? Icons.file_download : Icons.upload_file,
                      size: 40,
                      color: _isDragging
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  if (!_isProcessingBundle) ...[
                    const SizedBox(height: 8),
                    Text(
                      _isDragging
                          ? 'Release to add file or bundle'
                          : (_picked == null
                              ? 'Drag & drop or click to select files and bundles'
                              : _picked!.name),
                      style: TextStyle(
                        color: _isDragging
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        fontWeight: _isDragging ? FontWeight.w500 : null,
                      ),
                    ),
                    if (_isDragging)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '(.xcarchive bundles will be automatically zipped)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Remote folder selector
        Text('Remote Folder', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Builder(builder: (context) {
                final items = _buildFolderItems();
                return DropdownButtonFormField<String>(
                  value: _currentFolderValue(items),
                  hint: Text(_folderCtrl.text),
                  isExpanded: true,
                  items: items,
                  onChanged: (v) async {
                    setState(() => _folderCtrl.text = v ?? _folderCtrl.text);
                    widget.onFolderChanged?.call(_folderCtrl.text);
                    await _loadFolders(_folderCtrl.text);
                  },
                );
              }),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Create folder',
              onPressed: _createFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed:
                  _loadingFolders ? null : () => _loadFolders(_folderCtrl.text),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Browse…',
              onPressed: () async {
                final selected = await showDialog<String>(
                  context: context,
                  builder: (_) =>
                      FolderPickerDialog(initialPath: _folderCtrl.text),
                );
                if (selected != null && selected.isNotEmpty) {
                  setState(() => _folderCtrl.text = selected);
                  widget.onFolderChanged?.call(_folderCtrl.text);
                  await _loadFolders(_folderCtrl.text);
                }
              },
              icon: const Icon(Icons.folder_open),
            ),
            IconButton(
              tooltip: 'Up one level',
              onPressed: () async {
                final p = _parentOf(_folderCtrl.text);
                setState(() => _folderCtrl.text = p);
                widget.onFolderChanged?.call(_folderCtrl.text);
                await _loadFolders(_folderCtrl.text);
              },
              icon: const Icon(Icons.arrow_upward),
            ),
          ],
        ),

        const SizedBox(height: 16),
        // Chunk size (UI)
        Text('Chunk size', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          value: _chunkSizeMB,
          items: const [1, 2, 4, 8, 16, 32]
              .map((e) => DropdownMenuItem(value: e, child: Text('$e MB')))
              .toList(),
          onChanged: (v) => setState(() => _chunkSizeMB = v ?? _chunkSizeMB),
        ),

        const SizedBox(height: 16),
        // Custom filename
        TextFormField(
          controller: _fileNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Custom filename',
            helperText: 'Bundles will be automatically renamed to .zip',
          ),
        ),

        const SizedBox(height: 16),
        // Upload button + progress
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Execute upload'),
            onPressed:
                _picked == null || upload.uploading || _isProcessingBundle
                    ? null
                    : _upload,
          ),
        ),
        if (upload.uploading) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
              value: upload.progress == null
                  ? null
                  : upload.progress!.progressPercentage / 100.0),
          const SizedBox(height: 6),
          Text(upload.progress == null
              ? 'Starting…'
              : '${upload.progress!.fileName} — ${upload.progress!.progressPercentage.toStringAsFixed(0)}%'),
        ],

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],

        if (_link != null) ...[
          const SizedBox(height: 16),
          Text('Shareable link', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SelectableText(_link!),
              ),
              IconButton(
                tooltip: 'Copy',
                onPressed: () => Clipboard.setData(ClipboardData(text: _link!)),
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
        ],
      ],
    ));
  }
}
