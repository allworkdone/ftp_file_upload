import 'package:file_upload/app/theme/app_colors.dart';
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
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: Colors.white,
        title: const Text(
          'Upload Interface',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Choose Folder',
            icon: Icon(Icons.folder_open, color: AppColors.primaryLight),
            onPressed: _pickFolder,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: FileUploadWidget(
                folderPath: _folder,
                onFolderChanged: (p) => setState(() => _folder = p),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
