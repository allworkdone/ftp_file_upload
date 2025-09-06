// lib/features/authentication/presentation/views/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../../domain/entities/ftp_credentials.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart'; // Import your purple theme

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
  bool _saveCredentials = true;
  final FocusNode _hostFocus = FocusNode();
  final FocusNode _portFocus = FocusNode();
  final FocusNode _userFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();

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
    _hostFocus.dispose();
    _portFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _clearSavedCredentials() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title: const Text('Clear Saved Credentials',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to clear all saved login credentials? '
          'You will need to enter them again next time.',
          style: TextStyle(color: Colors.white70),
        ),
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
          SnackBar(
            content: const Text('Saved credentials cleared'),
            backgroundColor: Colors.orange.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Neon glow effect for focused fields
  BoxDecoration _buildNeonGlow(bool hasFocus) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: hasFocus
          ? [
              BoxShadow(
                color: AppColors.primaryLight.withOpacity(0.8),
                blurRadius: 15,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppColors.primary.withOpacity(0.6),
                blurRadius: 25,
                spreadRadius: 1,
              ),
            ]
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewModelProvider);
    final hasCredentials = auth.credentials != null;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 40),
                // App Logo/Title with neon effect
                const Center(
                  child: Text(
                    'UPFLOW',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                          color: AppColors.primaryLight,
                          blurRadius: 20,
                        ),
                        Shadow(
                          color: AppColors.primary,
                          blurRadius: 40,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'FTP Client',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                if (hasCredentials) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
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
                        Icon(Icons.check_circle, color: Colors.green[300]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Credentials loaded for ${auth.credentials!.hostname}',
                            style: TextStyle(color: Colors.green[300]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Host Field
                Focus(
                  onFocusChange: (hasFocus) => setState(() {}),
                  child: Container(
                    decoration: _buildNeonGlow(_hostFocus.hasFocus),
                    child: TextFormField(
                      controller: _hostController,
                      focusNode: _hostFocus,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Host',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'e.g., 192.168.255.53',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon:
                            Icon(Icons.dns, color: AppColors.primaryLight),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppColors.primaryLight.withOpacity(0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppColors.primaryLight.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.primaryLight, width: 2),
                        ),
                        filled: true,
                        fillColor: AppColors.darkSurface.withOpacity(0.8),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Port Field
                Focus(
                  onFocusChange: (hasFocus) => setState(() {}),
                  child: Container(
                    decoration: _buildNeonGlow(_portFocus.hasFocus),
                    child: TextFormField(
                      controller: _portController,
                      focusNode: _portFocus,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Port',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: '21',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: Icon(Icons.settings_ethernet,
                            color: AppColors.primaryLight),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppColors.primaryLight.withOpacity(0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppColors.primaryLight.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.primaryLight, width: 2),
                        ),
                        filled: true,
                        fillColor: AppColors.darkSurface.withOpacity(0.8),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final p = int.tryParse(v ?? '');
                        if (p == null || p <= 0 || p > 65535)
                          return 'Invalid port';
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Username Field
                Focus(
                  onFocusChange: (hasFocus) => setState(() {}),
                  child: Container(
                    decoration: _buildNeonGlow(_userFocus.hasFocus),
                    child: TextFormField(
                      controller: _userController,
                      focusNode: _userFocus,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Enter username',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon:
                            Icon(Icons.person, color: AppColors.primaryLight),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppColors.primaryLight.withOpacity(0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppColors.primaryLight.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.primaryLight, width: 2),
                        ),
                        filled: true,
                        fillColor: AppColors.darkSurface.withOpacity(0.8),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password Field
                Focus(
                  onFocusChange: (hasFocus) => setState(() {}),
                  child: Container(
                    decoration: _buildNeonGlow(_passFocus.hasFocus),
                    child: TextFormField(
                      controller: _passController,
                      focusNode: _passFocus,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Enter password',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon:
                            Icon(Icons.lock, color: AppColors.primaryLight),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppColors.primaryLight.withOpacity(0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppColors.primaryLight.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.primaryLight, width: 2),
                        ),
                        filled: true,
                        fillColor: AppColors.darkSurface.withOpacity(0.8),
                      ),
                      obscureText: true,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Toggle Switches
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.primaryLight.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Use FTPS (secure)',
                            style: TextStyle(color: Colors.white)),
                        subtitle: const Text('Encrypt FTP connection',
                            style: TextStyle(color: Colors.white70)),
                        value: _secure,
                        activeColor: AppColors.primaryLight,
                        onChanged: (v) => setState(() => _secure = v),
                      ),
                      SwitchListTile(
                        title: const Text('Save credentials',
                            style: TextStyle(color: Colors.white)),
                        subtitle: const Text('Remember login details',
                            style: TextStyle(color: Colors.white70)),
                        value: _saveCredentials,
                        activeColor: AppColors.primaryLight,
                        onChanged: (v) => setState(() => _saveCredentials = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (auth.testing)
                  LinearProgressIndicator(
                    backgroundColor: AppColors.darkSurface,
                    color: AppColors.primaryLight,
                    minHeight: 2,
                  ),

                if (auth.error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
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
                            auth.error!,
                            style: TextStyle(color: Colors.red[300]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Login Buttons
                _buildNeonButton(
                  onPressed: auth.testing ? null : _testAndLogin,
                  icon: Icons.login,
                  label: 'TEST & LOGIN',
                  isPrimary: true,
                ),

                if (hasCredentials) ...[
                  const SizedBox(height: 12),
                  _buildNeonButton(
                    onPressed: auth.testing ? null : _quickLogin,
                    icon: Icons.flash_on,
                    label: 'QUICK LOGIN',
                    isPrimary: false,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeonButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: isPrimary
                      ? AppColors.primaryLight.withOpacity(0.6)
                      : Colors.white.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: isPrimary
                      ? AppColors.primary.withOpacity(0.4)
                      : Colors.white.withOpacity(0.1),
                  blurRadius: 25,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon,
            color: isPrimary ? Colors.white : AppColors.primaryLight),
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPrimary ? Colors.white : AppColors.primaryLight,
            letterSpacing: 1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppColors.primary : Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isPrimary
                  ? AppColors.primaryLight
                  : AppColors.primaryLight.withOpacity(0.5),
              width: 2,
            ),
          ),
          elevation: 0,
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
