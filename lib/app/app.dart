import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../core/di/injection.dart';
import '../core/utils/app_logger.dart';

class FTPManagerApp extends ConsumerStatefulWidget {
  const FTPManagerApp({super.key});

  @override
  ConsumerState<FTPManagerApp> createState() => _FTPManagerAppState();
}

class _FTPManagerAppState extends ConsumerState<FTPManagerApp>
    with WidgetsBindingObserver {
  final _appRouter = getIt<AppRouter>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLogger.info('FTP Manager App initialized');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    AppLogger.info('App lifecycle changed to: $state');

    switch (state) {
      case AppLifecycleState.paused:
        // Handle app going to background
        break;
      case AppLifecycleState.resumed:
        // Handle app coming to foreground
        break;
      case AppLifecycleState.inactive:
        // Handle app becoming inactive
        break;
      case AppLifecycleState.detached:
        // Handle app being detached
        break;
      case AppLifecycleState.hidden:
        // Handle app being hidden
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FTP Manager',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // Router configuration
      routerConfig: _appRouter.router,

      // Error handling
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0), // Prevent text scaling
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },

      // Localization
      locale: const Locale('en', 'US'),
      supportedLocales: const [Locale('en', 'US')],
    );
  }
}
