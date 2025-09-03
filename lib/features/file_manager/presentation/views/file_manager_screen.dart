import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_names.dart';

import '../viewmodels/file_manager_viewmodel.dart';

class FileManagerScreen extends ConsumerWidget {
  const FileManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fileManagerViewModelProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Manager'),
        actions: [
          IconButton(
            tooltip: 'Browse Root',
            icon: const Icon(Icons.folder_open),
            onPressed: () => context.go(RouteNames.folderBrowserPath('/')),
          ),
          IconButton(
            tooltip: 'Upload',
            icon: const Icon(Icons.cloud_upload_outlined),
            onPressed: () => context.go(RouteNames.uploadPath(folderPath: state.currentPath)),
          ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(fileManagerViewModelProvider.notifier).refresh(state.currentPath),
              child: ListView(
                children: [
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(state.error!, style: const TextStyle(color: Colors.red)),
                    ),
                  ...state.folders.map((f) => ListTile(
                        leading: const Icon(Icons.folder),
                        title: Text(f.name),
                        onTap: () => context.go(RouteNames.folderBrowserPath(f.fullPath)),
                      )),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await showDialog<String>(
              context: context,
              builder: (ctx) {
                final c = TextEditingController();
                return AlertDialog(
                  title: const Text('Create Folder'),
                  content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Folder name')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Create')),
                  ],
                );
              });
          if (name != null && name.isNotEmpty) {
            await ref.read(fileManagerViewModelProvider.notifier).createFolderInCurrent(name);
          }
        },
        child: const Icon(Icons.create_new_folder_outlined),
      ),
    );
  }
}
