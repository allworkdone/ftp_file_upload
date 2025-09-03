import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/upload_record.dart';
import '../../domain/usecases/get_upload_history_usecase.dart';
import '../../domain/usecases/clear_history_usecase.dart';
import '../../../../core/di/injection.dart';

class UploadHistoryScreen extends ConsumerStatefulWidget {
  const UploadHistoryScreen({super.key});

  @override
  ConsumerState<UploadHistoryScreen> createState() => _UploadHistoryScreenState();
}

class _UploadHistoryScreenState extends ConsumerState<UploadHistoryScreen> {
  List<UploadRecord> _items = const [];
  bool _loading = true;

  Future<void> _load() async {
    setState(() => _loading = true);
    _items = await getIt<GetUploadHistoryUsecase>()();
    setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload History'),
        actions: [
          IconButton(
            onPressed: () async {
              await getIt<ClearHistoryUsecase>()();
              await _load();
            },
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear',
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No uploads yet'))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = _items[i];
                    return ListTile(
                      title: Text(r.fileName),
                      subtitle: Text('${r.formattedFileSize} • ${r.formattedDuration} • ${r.targetFolderPath}'),
                      trailing: Icon(r.isSuccessful ? Icons.check_circle : Icons.error, color: r.isSuccessful ? Colors.green : Colors.red),
                    );
                  },
                ),
    );
  }
}

