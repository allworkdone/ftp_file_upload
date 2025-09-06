import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/router/route_names.dart';

import '../viewmodels/file_manager_viewmodel.dart';
import '../../../authentication/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/usecases/delete_folder_usecase.dart';
import '../../../../core/di/injection.dart';
import '../../../../app/theme/app_colors.dart'; // Import your purple theme

class FileManagerScreen extends ConsumerWidget {
  const FileManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fileManagerViewModelProvider);
    final auth = ref.watch(authViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: Colors.white,
        title:
            const Text('File Manager', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Browse Root',
            icon: Icon(Icons.folder_open, color: AppColors.primaryLight),
            onPressed: () => context.go(RouteNames.folderBrowserPath('/')),
          ),
          IconButton(
            tooltip: 'Upload',
            icon: Icon(Icons.cloud_upload_outlined,
                color: AppColors.primaryLight),
            onPressed: () => context
                .go(RouteNames.uploadPath(folderPath: state.currentPath)),
          ),
          PopupMenuButton<String>(
            color: AppColors.darkSurface,
            icon: Icon(Icons.more_vert, color: AppColors.primaryLight),
            onSelected: (value) async {
              switch (value) {
                case 'logout':
                  await _showLogoutDialog(context, ref);
                  break;
                case 'settings':
                  context.go(RouteNames.connectionSetup);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: AppColors.primaryLight),
                    const SizedBox(width: 8),
                    const Text('Connection Settings',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red[300]),
                    const SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red[300])),
                  ],
                ),
              ),
            ],
          ),
        ],
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
        child: state.loading
            ? Center(
                child: CircularProgressIndicator(
                  year2023: false,
                  color: AppColors.primaryLight,
                  backgroundColor: AppColors.darkSurface,
                ),
              )
            : RefreshIndicator(
                backgroundColor: AppColors.darkSurface,
                color: AppColors.primaryLight,
                onRefresh: () => ref
                    .read(fileManagerViewModelProvider.notifier)
                    .refresh(state.currentPath),
                child: ListView(
                  children: [
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.4)),
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
                                  state.error!,
                                  style: TextStyle(color: Colors.red[300]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Connection info
                    if (auth.credentials != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.2),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.cloud_done, color: Colors.green[300]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Connected to ${auth.credentials!.hostname}:${auth.credentials!.port}',
                                  style: TextStyle(color: Colors.green[300]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Current path
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Text(
                        'Path: ${state.currentPath}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),

                    // Folders list
                    ...state.folders.map((f) => Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.darkSurface.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.primaryLight.withOpacity(0.2)),
                          ),
                          child: ListTile(
                            leading:
                                Icon(Icons.folder, color: Colors.amber[300]),
                            title: Text(f.name,
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text('Folder • ${f.totalFiles} files',
                                style: const TextStyle(color: Colors.white70)),
                            onTap: () => context
                                .go(RouteNames.folderBrowserPath(f.fullPath)),
                            trailing: PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert,
                                  color: AppColors.primaryLight),
                              onSelected: (value) async {
                                switch (value) {
                                  case 'delete':
                                    await _showDeleteFolderDialog(
                                        context, ref, f.name, f.fullPath);
                                    break;
                                  case 'open':
                                    final url =
                                        'https://project.ibartstech.com${f.fullPath}';
                                    final uri = Uri.parse(url);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'open',
                                  child: Row(
                                    children: [
                                      Icon(Icons.open_in_browser,
                                          color: AppColors.primaryLight),
                                      const SizedBox(width: 8),
                                      const Text('Open in browser',
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete,
                                          color: Colors.red[300]),
                                      const SizedBox(width: 8),
                                      Text('Delete',
                                          style: TextStyle(
                                              color: Colors.red[300])),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),

                    if (state.folders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.folder_open,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              const Text('No folders found',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 18)),
                              const SizedBox(height: 8),
                              const Text('Create a new folder or upload files',
                                  style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateFolderDialog(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: Icon(Icons.create_new_folder_outlined, color: Colors.white),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
            'Are you sure you want to logout? You will need to login again.',
            style: TextStyle(color: Colors.white70)),
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
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(authViewModelProvider.notifier).logout();
      if (context.mounted) {
        context.go(RouteNames.login);
      }
    }
  }

  Future<void> _showCreateFolderDialog(
      BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title:
            const Text('Create Folder', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Folder name',
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: 'Enter folder name',
            hintStyle: const TextStyle(color: Colors.white54),
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
              borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
            ),
            filled: true,
            fillColor: AppColors.darkSurface.withOpacity(0.8),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      try {
        await ref
            .read(fileManagerViewModelProvider.notifier)
            .createFolderInCurrent(name);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Folder "$name" created successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create folder: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _showDeleteFolderDialog(BuildContext context, WidgetRef ref,
      String folderName, String folderPath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title:
            const Text('Delete Folder', style: TextStyle(color: Colors.white)),
        content: Text(
            'Are you sure you want to delete "$folderName"?\n\nThis action cannot be undone and will delete all contents.',
            style: const TextStyle(color: Colors.white70)),
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

    if (confirmed == true) {
      try {
        await getIt<DeleteFolderUsecase>()(folderPath);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Folder "$folderName" deleted successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Refresh the current view
          ref
              .read(fileManagerViewModelProvider.notifier)
              .refresh(ref.read(fileManagerViewModelProvider).currentPath);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete folder: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}
