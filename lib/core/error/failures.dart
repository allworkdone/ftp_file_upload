import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

// Server Failures
class ServerFailure extends Failure {
  const ServerFailure(String message, {String? code}) 
      : super(message, code: code);
}

class FTPConnectionFailure extends Failure {
  const FTPConnectionFailure(String message, {String? code}) 
      : super(message, code: code);
}

class FTPAuthenticationFailure extends Failure {
  const FTPAuthenticationFailure(String message, {String? code}) 
      : super(message, code: code);
}

class FTPUploadFailure extends Failure {
  const FTPUploadFailure(String message, {String? code}) 
      : super(message, code: code);
}

class FTPDirectoryFailure extends Failure {
  const FTPDirectoryFailure(String message, {String? code}) 
      : super(message, code: code);
}

// Local Failures
class CacheFailure extends Failure {
  const CacheFailure(String message, {String? code}) 
      : super(message, code: code);
}

class FileSystemFailure extends Failure {
  const FileSystemFailure(String message, {String? code}) 
      : super(message, code: code);
}

class PermissionFailure extends Failure {
  const PermissionFailure(String message, {String? code}) 
      : super(message, code: code);
}

// Network Failures
class NetworkFailure extends Failure {
  const NetworkFailure(String message, {String? code}) 
      : super(message, code: code);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure(String message, {String? code}) 
      : super(message, code: code);
}

// Validation Failures
class ValidationFailure extends Failure {
  const ValidationFailure(String message, {String? code}) 
      : super(message, code: code);
}

class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure(String message, {String? code}) 
      : super(message, code: code);
}

// General Failures
class UnknownFailure extends Failure {
  const UnknownFailure(String message, {String? code}) 
      : super(message, code: code);
}

class CancelledFailure extends Failure {
  const CancelledFailure(String message, {String? code}) 
      : super(message, code: code);
}