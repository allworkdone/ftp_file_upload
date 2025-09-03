import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../viewmodels/upload_viewmodel.dart';
import '../../../file_manager/data/datasources/local_file_datasource.dart';
import '../../../../core/di/injection.dart';

class UploadScreen extends ConsumerStatefulWidget {
  final String targetFolderPath;
  const UploadScreen({super.key, required this.targetFolderPath});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  PlatformFile? _picked;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uploadViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Upload File')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target folder: ${widget.targetFolderPath}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                _picked = await getIt<LocalFileDatasource>().pickSingleFile();
                setState(() {});
              },
              child: const Text('Choose File'),
            ),
            const SizedBox(height: 16),
            if (_picked != null) Text('Selected: ${_picked!.name}'),
            const SizedBox(height: 16),
              if (state.uploading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(state.progress == null
                    ? 'Uploading...'
                    : '${state.progress!.fileName}: ${state.progress!.progressPercentage.toStringAsFixed(0)}%'),
              ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _picked == null || state.uploading
                    ? null
                    : () async {
                        final remotePath = '${widget.targetFolderPath.replaceAll(RegExp(r"/+") , '/')}/${_picked!.name}'.replaceAll(RegExp(r"/+"), '/');
                        await ref.read(uploadViewModelProvider.notifier).upload(_picked!.path!, remotePath);
                        if (!mounted) return;
                        if (ref.read(uploadViewModelProvider).error == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload complete')));
                        }
                      },
                child: const Text('Upload'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
