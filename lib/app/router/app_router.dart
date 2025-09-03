import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import 'route_names.dart';
import '../../features/authentication/presentation/views/login_screen.dart';
import '../../features/authentication/presentation/views/connection_setup_screen.dart';
import '../../features/file_manager/presentation/views/file_manager_screen.dart';
import '../../features/file_manager/presentation/views/folder_browser_screen.dart';
import '../../features/file_manager/presentation/views/upload_screen.dart';
import '../../features/upload_history/presentation/views/upload_history_screen.dart';
import '../../features/settings/presentation/views/settings_screen.dart';

class AppRouter {
  late final GoRouter _router;

  AppRouter() {
    _router = GoRouter(
      initialLocation: RouteNames.login,
      debugLogDiagnostics: true,
      routes: [
        // Authentication Routes
        GoRoute(
          path: RouteNames.login,
          name: RouteNames.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: RouteNames.connectionSetup,
          name: RouteNames.connectionSetup,
          builder: (context, state) => const ConnectionSetupScreen(),
        ),

        // Main App Routes
        GoRoute(
          path: RouteNames.fileManager,
          name: RouteNames.fileManager,
          builder: (context, state) => const FileManagerScreen(),
          routes: [
            GoRoute(
              path: 'folder/:folderPath',
              name: RouteNames.folderBrowser,
              builder: (context, state) {
                final raw = state.pathParameters['folderPath'] ?? '';
                final folderPath = Uri.decodeComponent(raw);
                return FolderBrowserScreen(folderPath: folderPath);
              },
            ),
            GoRoute(
              path: 'upload',
              name: RouteNames.upload,
              builder: (context, state) {
                final folderPath =
                    state.uri.queryParameters['folderPath'] ?? '';
                return UploadScreen(targetFolderPath: folderPath);
              },
            ),
          ],
        ),

        // Upload History Route
        GoRoute(
          path: RouteNames.uploadHistory,
          name: RouteNames.uploadHistory,
          builder: (context, state) => const UploadHistoryScreen(),
        ),

        // Settings Route
        GoRoute(
          path: RouteNames.settings,
          name: RouteNames.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Page Not Found',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'The page "${state.matchedLocation}" could not be found.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(RouteNames.fileManager),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
      redirect: (context, state) {
        // Add authentication checks here if needed
        // For now, allow all routes
        return null;
      },
    );
  }

  GoRouter get router => _router;
}
