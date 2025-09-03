import 'package:flutter/material.dart';

import '../../../file_manager/domain/entities/ftp_folder.dart';
import '../../../file_manager/domain/entities/ftp_file.dart';
import '../../../file_manager/domain/usecases/get_folders_usecase.dart';
import '../../../file_manager/domain/usecases/get_files_usecase.dart';
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
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (_folders.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('Folders', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ..._folders.map((f) => ListTile(
                        leading: const Icon(Icons.folder),
                        title: Text(f.name),
                        onTap: () => context.push(RouteNames.folderBrowserPath(f.fullPath)),
                      )),
                  if (_files.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('Files', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ..._files.map((fi) => ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(fi.name),
                        subtitle: Text(fi.path),
                      )),
                  if (_folders.isEmpty && _files.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Folder is empty')),
                    ),
                ],
              ),
            ),
    );
  }
}
