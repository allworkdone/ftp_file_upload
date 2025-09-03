import '../entities/ftp_credentials.dart';
import '../repositories/auth_repository.dart';

class SaveCredentialsUsecase {
  final AuthRepository _repository;
  SaveCredentialsUsecase(this._repository);

  Future<void> call(FTPCredentials credentials) => _repository.saveCredentials(credentials);
}
