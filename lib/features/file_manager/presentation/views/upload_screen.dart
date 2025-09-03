import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/file_upload_widget.dart';
import '../widgets/folder_picker_dialog.dart';

class UploadScreen extends ConsumerStatefulWidget {
  final String targetFolderPath;
  const UploadScreen({super.key, required this.targetFolderPath});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  late String _folder;

  @override
  void initState() {
    super.initState();
    _folder = widget.targetFolderPath.isEmpty ? '/' : widget.targetFolderPath;
  }

  Future<void> _pickFolder() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => FolderPickerDialog(initialPath: _folder),
    );
    if (selected != null && selected.isNotEmpty) {
      setState(() => _folder = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Interface'),
        actions: [
          IconButton(
            tooltip: 'Choose Folder',
            icon: const Icon(Icons.folder_open),
            onPressed: _pickFolder,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FileUploadWidget(folderPath: _folder, onFolderChanged: (p) => setState(() => _folder = p)),
          ),
        ),
      ),
    );
  }
}
