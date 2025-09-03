import 'package:file_upload/core/error/failures.dart';

class ServerException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  const ServerException(this.message, {this.code, this.statusCode});

  @override
  String toString() => 'ServerException: $message';
}

class FTPException implements Exception {
  final String message;
  final String? code;
  final FTPExceptionType type;

  const FTPException(this.message, this.type, {this.code});

  @override
  String toString() => 'FTPException: $message (${type.name})';
}

enum FTPExceptionType {
  connection,
  authentication,
  upload,
  download,
  directory,
  permission,
  timeout,
  unknown,
}

class CacheException implements Exception {
  final String message;
  final String? code;

  const CacheException(this.message, {this.code});

  @override
  String toString() => 'CacheException: $message';
}

class FileSystemException implements Exception {
  final String message;
  final String? code;
  final String? path;

  const FileSystemException(this.message, {this.code, this.path});

  @override
  String toString() =>
      'FileSystemException: $message${path != null ? ' (Path: $path)' : ''}';
}

class NetworkException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  const NetworkException(this.message, {this.code, this.statusCode});

  @override
  String toString() => 'NetworkException: $message';
}

class ValidationException implements Exception {
  final String message;
  final String? field;
  final String? code;

  const ValidationException(this.message, {this.field, this.code});

  @override
  String toString() =>
      'ValidationException: $message${field != null ? ' (Field: $field)' : ''}';
}

class PermissionException implements Exception {
  final String message;
  final String? permission;
  final String? code;

  const PermissionException(this.message, {this.permission, this.code});

  @override
  String toString() => 'PermissionException: $message';
}

class TimeoutException implements Exception {
  final String message;
  final Duration? timeout;
  final String? code;

  const TimeoutException(this.message, {this.timeout, this.code});

  @override
  String toString() =>
      'TimeoutException: $message${timeout != null ? ' (Timeout: ${timeout!.inSeconds}s)' : ''}';
}

// Exception to Failure conversion utility
class ExceptionHandler {
  static Failure handleException(Exception exception) {
    switch (exception.runtimeType) {
      case FTPException:
        final ftpException = exception as FTPException;
        switch (ftpException.type) {
          case FTPExceptionType.connection:
            return FTPConnectionFailure(
              ftpException.message,
              code: ftpException.code,
            );
          case FTPExceptionType.authentication:
            return FTPAuthenticationFailure(
              ftpException.message,
              code: ftpException.code,
            );
          case FTPExceptionType.upload:
            return FTPUploadFailure(
              ftpException.message,
              code: ftpException.code,
            );
          case FTPExceptionType.directory:
            return FTPDirectoryFailure(
              ftpException.message,
              code: ftpException.code,
            );
          case FTPExceptionType.timeout:
            return TimeoutFailure(
              ftpException.message,
              code: ftpException.code,
            );
          default:
            return ServerFailure(ftpException.message, code: ftpException.code);
        }

      case NetworkException:
        final networkException = exception as NetworkException;
        return NetworkFailure(
          networkException.message,
          code: networkException.code,
        );

      case CacheException:
        final cacheException = exception as CacheException;
        return CacheFailure(cacheException.message, code: cacheException.code);

      case FileSystemException:
        final fsException = exception as FileSystemException;
        return FileSystemFailure(fsException.message, code: fsException.code);

      case ValidationException:
        final validationException = exception as ValidationException;
        return ValidationFailure(
          validationException.message,
          code: validationException.code,
        );

      case PermissionException:
        final permissionException = exception as PermissionException;
        return PermissionFailure(
          permissionException.message,
          code: permissionException.code,
        );

      case TimeoutException:
        final timeoutException = exception as TimeoutException;
        return TimeoutFailure(
          timeoutException.message,
          code: timeoutException.code,
        );

      case ServerException:
        final serverException = exception as ServerException;
        return ServerFailure(
          serverException.message,
          code: serverException.code,
        );

      default:
        return UnknownFailure(
          'An unexpected error occurred: ${exception.toString()}',
        );
    }
  }

  static String getErrorMessage(Failure failure) {
    switch (failure.runtimeType) {
      case FTPConnectionFailure _:
        return 'Failed to connect to FTP server. Please check your credentials and internet connection.';
      case FTPAuthenticationFailure:
        return 'Authentication failed. Please verify your username and password.';
      case FTPUploadFailure:
        return 'File upload failed. Please try again.';
      case FTPDirectoryFailure:
        return 'Failed to access or create directory on FTP server.';
      case NetworkFailure:
        return 'Network error occurred. Please check your internet connection.';
      case FileSystemFailure:
        return 'File system error occurred. Please check file permissions.';
      case PermissionFailure:
        return 'Permission denied. Please grant necessary permissions in settings.';
      case ValidationFailure:
        return 'Invalid input provided. Please check your data.';
      case TimeoutFailure:
        return 'Operation timed out. Please try again.';
      case CacheFailure:
        return 'Local storage error occurred.';
      default:
        return failure.message.isNotEmpty
            ? failure.message
            : 'An unexpected error occurred.';
    }
  }
}
