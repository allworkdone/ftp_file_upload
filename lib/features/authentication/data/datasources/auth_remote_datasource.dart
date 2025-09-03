import 'package:ftpconnect/ftpconnect.dart';

import '../../domain/entities/ftp_credentials.dart';

abstract class AuthRemoteDatasource {
  Future<bool> testConnection(FTPCredentials credentials);
}

class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  @override
  Future<bool> testConnection(FTPCredentials credentials) async {
    final ftp = FTPConnect(
      credentials.hostname,
      user: credentials.username,
      pass: credentials.password,
      port: credentials.port,
      timeout: 15,
      securityType: credentials.isSecure ? SecurityType.FTPS : SecurityType.FTP,
    );
    try {
      final connected = await ftp.connect();
      if (connected) {
        await ftp.disconnect();
      }
      return true;
    } catch (_) {
      try {
        await ftp.disconnect();
      } catch (_) {}
      return false;
    }
  }
}
