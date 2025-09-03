import '../../domain/entities/ftp_credentials.dart';

class FTPCredentialsModel extends FTPCredentials {
  const FTPCredentialsModel({
    required super.hostname,
    required super.port,
    required super.username,
    required super.password,
    super.isSecure = false,
    super.lastUsed,
  });

  factory FTPCredentialsModel.fromEntity(FTPCredentials e) => FTPCredentialsModel(
        hostname: e.hostname,
        port: e.port,
        username: e.username,
        password: e.password,
        isSecure: e.isSecure,
        lastUsed: e.lastUsed,
      );

  Map<String, dynamic> toMap() => {
        'hostname': hostname,
        'port': port,
        'username': username,
        'password': password,
        'isSecure': isSecure,
        'lastUsed': lastUsed?.toIso8601String(),
      };

  factory FTPCredentialsModel.fromMap(Map map) => FTPCredentialsModel(
        hostname: map['hostname'] as String? ?? '',
        port: map['port'] as int? ?? 21,
        username: map['username'] as String? ?? '',
        password: map['password'] as String? ?? '',
        isSecure: map['isSecure'] as bool? ?? false,
        lastUsed: map['lastUsed'] != null ? DateTime.tryParse(map['lastUsed'] as String) : null,
      );
}
