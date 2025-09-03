import '../entities/ftp_credentials.dart';
import '../repositories/auth_repository.dart';

class GetCredentialsUsecase {
  final AuthRepository _repository;
  GetCredentialsUsecase(this._repository);

  Future<FTPCredentials?> call() => _repository.getCredentials();
}
