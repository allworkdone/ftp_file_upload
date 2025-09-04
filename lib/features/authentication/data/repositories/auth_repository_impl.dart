import '../../../../core/network/network_info.dart';
import '../../domain/entities/ftp_credentials.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthLocalDatasource localDataSource;
  final AuthRemoteDatasource remoteDataSource;
  final NetworkInfo networkInfo;

  AuthRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<FTPCredentials?> getCredentials() => localDataSource.getCredentials();

  @override
  Future<void> saveCredentials(FTPCredentials credentials) async {
    await localDataSource.saveCredentials(
      credentials.copyWith(lastUsed: DateTime.now()),
    );
  }

  @override
  Future<bool> testConnection(FTPCredentials credentials) async {
    if (!await networkInfo.isConnected) return false;
    return remoteDataSource.testConnection(credentials);
  }

  @override
  Future<void> clearCredentials() => localDataSource.clearCredentials(); // NEW
}
