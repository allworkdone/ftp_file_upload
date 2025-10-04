import '../../domain/entities/ftp_credentials.dart';
import '../../../../core/services/ftp_service.dart';

abstract class AuthRemoteDatasource {
  Future<bool> testConnection(FTPCredentials credentials);
}

class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  final FTPService _ftpService = FTPService(); // This should use the singleton

  @override
  Future<bool> testConnection(FTPCredentials credentials) async {
    print('AuthRemoteDatasourceImpl.testConnection: Testing connection to ${credentials.hostname}:${credentials.port}');
    try {
      // Use the FTP service to test the connection
      final connected = await _ftpService.testConnection(credentials);
      print('AuthRemoteDatasourceImpl.testConnection: Connection test result: $connected');
      return connected;
    } catch (e) {
      print('AuthRemoteDatasourceImpl.testConnection: Connection test failed: $e');
      return false;
    }
  }
}
