import 'package:logger/logger.dart';

class AppLogger {
  static Logger? _logger;
  static bool _isInitialized = false;

  static void init() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
    );
    _isInitialized = true;
  }

  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_isInitialized && _logger != null) {
      _logger!.d(message, error: error, stackTrace: stackTrace);
    } else {
      print('DEBUG: $message');
      if (error != null) print('Error: $error');
    }
  }

  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_isInitialized && _logger != null) {
      _logger!.i(message, error: error, stackTrace: stackTrace);
    } else {
      print('INFO: $message');
      if (error != null) print('Error: $error');
    }
  }

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_isInitialized && _logger != null) {
      _logger!.w(message, error: error, stackTrace: stackTrace);
    } else {
      print('WARNING: $message');
      if (error != null) print('Error: $error');
    }
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_isInitialized && _logger != null) {
      _logger!.e(message, error: error, stackTrace: stackTrace);
      print('ERROR: $message');
    } else {
      print('ERROR: $message');
      if (error != null) print('Error: $error');
      if (stackTrace != null) print('Stack trace: $stackTrace');
    }
  }
}
