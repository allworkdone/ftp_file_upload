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
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '21');
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _secure = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('FTP Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _hostController,
                decoration: const InputDecoration(labelText: 'Host'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(labelText: 'Port'),
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
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Use FTPS (secure)'),
                value: _secure,
                onChanged: (v) => setState(() => _secure = v),
              ),
              const SizedBox(height: 24),
              if (auth.testing) const LinearProgressIndicator(),
              if (auth.error != null) ...[
                Text(auth.error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: auth.testing
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              final creds = FTPCredentials(
                                hostname: _hostController.text.trim(),
                                port: int.parse(_portController.text.trim()),
                                username: _userController.text.trim(),
                                password: _passController.text,
                                isSecure: _secure,
                              );
                              final ok = await ref.read(authViewModelProvider.notifier).test(creds);
                              if (ok) {
                                await ref.read(authViewModelProvider.notifier).save(creds);
                                if (!mounted) return;
                                context.go(RouteNames.fileManager);
                              }
                            },
                      child: const Text('Test & Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
