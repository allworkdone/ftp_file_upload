import '../entities/ftp_credentials.dart';
import '../repositories/auth_repository.dart';

class TestConnectionUsecase {
  final AuthRepository _repository;
  TestConnectionUsecase(this._repository);

  Future<bool> call(FTPCredentials credentials) => _repository.testConnection(credentials);
}
