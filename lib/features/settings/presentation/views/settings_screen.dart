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
  final _baseUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _load() async {
    _settings = await getIt<GetSettingsUsecase>()();
    _baseUrlController.text = _settings.baseDownloadUrl;
    setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Update settings with current base URL from text field
    final updatedSettings = _settings.copyWith(
      baseDownloadUrl: _baseUrlController.text.trim(),
    );

    await getIt<UpdateSettingsUsecase>()(updatedSettings);
    _settings = updatedSettings;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  void _resetToDefault() {
    _baseUrlController.text = 'https://project.ibartstech.com';
    setState(() {
      _settings = _settings.copyWith(
        baseDownloadUrl: 'https://project.ibartstech.com',
      );
    });
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Base URL cannot be empty';
    }

    final url = value.trim();
    if (!Uri.tryParse(url)!.hasScheme == true) {
      return 'Please enter a valid URL (e.g., https://example.com)';
    }

    if (!url.startsWith('http://') &&
        !url.startsWith('https://') &&
        !url.startsWith('ftp://')) {
      return 'URL must start with http:// or https:// or ftp://';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Base URL Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.link),
                              const SizedBox(width: 8),
                              Text(
                                'Download Link Settings',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _baseUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Base Download URL',
                              hintText: 'https://your-domain.com',
                              helperText:
                                  'This URL will be used to generate download links',
                              prefixIcon: Icon(Icons.web),
                            ),
                            validator: _validateUrl,
                            onChanged: (value) {
                              setState(() {
                                _settings = _settings.copyWith(
                                  baseDownloadUrl: value.trim(),
                                );
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _resetToDefault,
                                icon: const Icon(Icons.restore, size: 16),
                                label: const Text('Reset to Default'),
                              ),
                              const Spacer(),
                              Text(
                                'Preview: ${_baseUrlController.text.isNotEmpty ? _baseUrlController.text : "Enter URL"}/path/file.txt',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Other Settings
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Notifications'),
                          subtitle:
                              const Text('Show upload/download notifications'),
                          value: _settings.enableNotifications,
                          onChanged: (v) => setState(() => _settings =
                              _settings.copyWith(enableNotifications: v)),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Require Wi-Fi for upload'),
                          subtitle:
                              const Text('Only upload when connected to Wi-Fi'),
                          value: _settings.requireWifiForUpload,
                          onChanged: (v) => setState(() => _settings =
                              _settings.copyWith(requireWifiForUpload: v)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
