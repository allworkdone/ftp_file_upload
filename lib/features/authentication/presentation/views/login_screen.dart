// lib/features/authentication/presentation/views/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../../domain/entities/ftp_credentials.dart';
import '../../../../app/router/route_names.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController(text: '195.26.255.53');
  final _portController = TextEditingController(text: '21');
  final _userController = TextEditingController(text: 'project@ibartstech.com');
  final _passController = TextEditingController(text: 'project@apk123@');
  bool _secure = false;
  bool _saveCredentials = true; // Default to save credentials

  @override
  void initState() {
    super.initState();
    // Load saved credentials when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedCredentials();
    });
  }

  void _loadSavedCredentials() {
    final auth = ref.read(authViewModelProvider);
    if (auth.credentials != null) {
      final creds = auth.credentials!;
      _hostController.text = creds.hostname;
      _portController.text = creds.port.toString();
      _userController.text = creds.username;
      _passController.text = creds.password;
      _secure = creds.isSecure;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _clearSavedCredentials() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Saved Credentials'),
        content: const Text(
          'Are you sure you want to clear all saved login credentials? '
          'You will need to enter them again next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authViewModelProvider.notifier).clearCredentials();
      _hostController.clear();
      _portController.text = '21';
      _userController.clear();
      _passController.clear();
      _secure = false;
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved credentials cleared'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewModelProvider);
    final hasCredentials = auth.credentials != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FTP Login'),
        actions: [
          if (hasCredentials)
            IconButton(
              onPressed: _clearSavedCredentials,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear saved credentials',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (hasCredentials) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Saved credentials loaded for ${auth.credentials!.hostname}',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Host',
                  hintText: 'e.g., 192.168.255.53',
                  prefixIcon: Icon(Icons.dns),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '21',
                  prefixIcon: Icon(Icons.settings_ethernet),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final p = int.tryParse(v ?? '');
                  if (p == null || p <= 0 || p > 65535) return 'Invalid port';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter username',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Use FTPS (secure)'),
                subtitle: const Text('Encrypt FTP connection'),
                value: _secure,
                onChanged: (v) => setState(() => _secure = v),
              ),
              SwitchListTile(
                title: const Text('Save credentials'),
                subtitle: const Text('Remember login details for next time'),
                value: _saveCredentials,
                onChanged: (v) => setState(() => _saveCredentials = v),
              ),
              const SizedBox(height: 24),
              if (auth.testing) const LinearProgressIndicator(),
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          auth.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: auth.testing ? null : _testAndLogin,
                      icon: const Icon(Icons.login),
                      label: const Text('Test & Login'),
                    ),
                  ),
                ],
              ),
              if (hasCredentials) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: auth.testing ? null : _quickLogin,
                        icon: const Icon(Icons.flash_on),
                        label: const Text('Quick Login'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _testAndLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final creds = FTPCredentials(
      hostname: _hostController.text.trim(),
      port: int.parse(_portController.text.trim()),
      username: _userController.text.trim(),
      password: _passController.text,
      isSecure: _secure,
    );

    final success = await ref.read(authViewModelProvider.notifier).test(creds);

    if (success) {
      if (_saveCredentials) {
        await ref.read(authViewModelProvider.notifier).save(creds);
      }

      if (!mounted) return;
      context.go(RouteNames.fileManager);
    }
  }

  Future<void> _quickLogin() async {
    final auth = ref.read(authViewModelProvider);
    if (auth.credentials == null) return;

    final success =
        await ref.read(authViewModelProvider.notifier).test(auth.credentials!);

    if (success && mounted) {
      context.go(RouteNames.fileManager);
    }
  }
}
