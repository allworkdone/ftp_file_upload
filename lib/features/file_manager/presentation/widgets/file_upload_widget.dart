import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

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
  const FileUploadWidget({super.key, required this.folderPath, this.onFolderChanged});

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
  int _chunkSizeMB = 4; // UI-only; ftpconnect doesn't support manual chunking
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
    _folderCtrl = TextEditingController(text: widget.folderPath.isEmpty ? '/' : widget.folderPath);
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

  Future<void> _pickFile() async {
    _picked = await getIt<LocalFileDatasource>().pickSingleFile();
    if (_picked != null) {
      _fileNameCtrl.text = _picked!.name;
    }
    setState(() {});
  }

  Future<void> _createFolder() async {
    final nameCtrl = TextEditingController();
    final created = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Folder name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (created != null && created.isNotEmpty) {
      final base = _folderCtrl.text.trim();
      final newPath = (
        '${base.endsWith('/') ? base : base + '/'}$created'
      ).replaceAll(RegExp(r"/+"), '/');
      await getIt<CreateFolderUsecase>()(newPath);
      _folderCtrl.text = newPath;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Folder created: $newPath')));
      }
    }
  }

  Future<void> _upload() async {
    setState(() { _link = null; _error = null; });
    final file = _picked;
    if (file == null) return;
    final folder = _folderCtrl.text.trim().isEmpty ? '/' : _folderCtrl.text.trim();
    final fileName = _fileNameCtrl.text.trim().isEmpty ? file.name : _fileNameCtrl.text.trim();
    final remotePath = (
      '${folder.endsWith('/') ? folder : folder + '/'}$fileName'
    ).replaceAll(RegExp(r"/+"), '/');

    try {
      await ref.read(uploadViewModelProvider.notifier).upload(file.path!, remotePath);
      final state = ref.read(uploadViewModelProvider);
      if (state.error != null) {
        setState(() => _error = state.error);
        return;
      }
      final link = getIt<GenerateLinkUsecase>().fileUrl(folder.replaceFirst(RegExp('^/'), ''), fileName);
      setState(() => _link = link);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final upload = ref.watch(uploadViewModelProvider);
    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Client-side Upload', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        // Pick area
        InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.4), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_picked != null && (_picked!.extension?.toLowerCase().contains('png') == true ||
                    _picked!.extension?.toLowerCase().contains('jpg') == true ||
                    _picked!.extension?.toLowerCase().contains('jpeg') == true ||
                    _picked!.extension?.toLowerCase().contains('webp') == true ||
                    _picked!.extension?.toLowerCase().contains('gif') == true))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _picked!.path != null
                        ? Image.file(
                            File(_picked!.path!),
                            height: 120,
                            fit: BoxFit.cover,
                          )
                        : (_picked!.bytes != null
                            ? Image.memory(_picked!.bytes!, height: 120, fit: BoxFit.cover)
                            : const Icon(Icons.image, size: 40)),
                  )
                else
                  const Icon(Icons.upload_file, size: 40),
                const SizedBox(height: 8),
                Text(_picked == null ? 'Drag n drop or click to select' : _picked!.name),
              ],
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
              onPressed: _loadingFolders ? null : () => _loadFolders(_folderCtrl.text),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Browse…€¦',
              onPressed: () async {
                final selected = await showDialog<String>(
                  context: context,
                  builder: (_) => FolderPickerDialog(initialPath: _folderCtrl.text),
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
          decoration: const InputDecoration(labelText: 'Custom filename'),
        ),

        const SizedBox(height: 16),
        // Upload button + progress
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Execute upload'),
            onPressed: _picked == null || upload.uploading ? null : _upload,
          ),
        ),
        if (upload.uploading) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: upload.progress == null ? null : upload.progress!.progressPercentage / 100.0),
          const SizedBox(height: 6),
          Text(upload.progress == null ? 'Starting…€¦' : '${upload.progress!.fileName} â€” ${upload.progress!.progressPercentage.toStringAsFixed(0)}%'),
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




