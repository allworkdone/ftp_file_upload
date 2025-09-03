import 'package:equatable/equatable.dart';

class FTPCredentials extends Equatable {
  final String hostname;
  final int port;
  final String username;
  final String password;
  final bool isSecure;
  final DateTime? lastUsed;

  const FTPCredentials({
    required this.hostname,
    required this.port,
    required this.username,
    required this.password,
    this.isSecure = false,
    this.lastUsed,
  });

  FTPCredentials copyWith({
    String? hostname,
    int? port,
    String? username,
    String? password,
    bool? isSecure,
    DateTime? lastUsed,
  }) {
    return FTPCredentials(
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      isSecure: isSecure ?? this.isSecure,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  bool get isValid {
    return hostname.isNotEmpty &&
        port > 0 &&
        port <= 65535 &&
        username.isNotEmpty &&
        password.isNotEmpty;
  }

  @override
  List<Object?> get props => [
    hostname,
    port,
    username,
    password,
    isSecure,
    lastUsed,
  ];
}
