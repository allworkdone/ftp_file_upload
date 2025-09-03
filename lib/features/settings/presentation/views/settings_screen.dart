import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_settings.dart' as domain;
import '../../domain/usecases/get_settings_usecase.dart';
import '../../domain/usecases/update_settings_usecase.dart';
import '../../../../core/di/injection.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late domain.AppSettings _settings;
  bool _loading = true;

  Future<void> _load() async {
    _settings = await getIt<GetSettingsUsecase>()();
    setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _save() async {
    await getIt<UpdateSettingsUsecase>()(_settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [IconButton(onPressed: _loading ? null : _save, icon: const Icon(Icons.save))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Notifications'),
                  value: _settings.enableNotifications,
                  onChanged: (v) => setState(() => _settings = _settings.copyWith(enableNotifications: v)),
                ),
                SwitchListTile(
                  title: const Text('Require Wi-Fi for upload'),
                  value: _settings.requireWifiForUpload,
                  onChanged: (v) => setState(() => _settings = _settings.copyWith(requireWifiForUpload: v)),
                ),
              ],
            ),
    );
  }
}

