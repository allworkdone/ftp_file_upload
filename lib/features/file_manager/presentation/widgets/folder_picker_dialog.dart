import 'package:flutter/material.dart';

import '../../../file_manager/domain/entities/ftp_folder.dart';
import '../../../file_manager/domain/usecases/get_folders_usecase.dart';
import '../../../../core/di/injection.dart';

class FolderPickerDialog extends StatefulWidget {
  final String initialPath;
  const FolderPickerDialog({super.key, required this.initialPath});

  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  late String _path;
  bool _loading = true;
  String? _error;
  List<FTPFolder> _folders = const [];

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath.isEmpty ? '/' : widget.initialPath;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _folders = await getIt<GetFoldersUsecase>()(_path);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goUp() {
    if (_path == '/' || _path.isEmpty) return;
    final p = _path.endsWith('/') ? _path.substring(0, _path.length - 1) : _path;
    final i = p.lastIndexOf('/');
    _path = i <= 0 ? '/' : p.substring(0, i);
    _load();
  }

  void _enter(FTPFolder f) {
    _path = f.fullPath;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Folder'),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_path, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.arrow_upward),
                          title: const Text('..'),
                          onTap: _goUp,
                        ),
                        ..._folders.map((f) => ListTile(
                              leading: const Icon(Icons.folder),
                              title: Text(f.name),
                              onTap: () => _enter(f),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, _path), child: const Text('Select')),
      ],
    );
  }
}

