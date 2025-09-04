import '../entities/ftp_credentials.dart';

abstract class AuthRepository {
  Future<void> saveCredentials(FTPCredentials credentials);
  Future<FTPCredentials?> getCredentials();
  Future<bool> testConnection(FTPCredentials credentials);
  Future<void> clearCredentials();
}
