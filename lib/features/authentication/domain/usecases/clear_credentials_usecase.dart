import '../repositories/auth_repository.dart';

class ClearCredentialsUsecase {
  final AuthRepository _repository;
  ClearCredentialsUsecase(this._repository);

  Future<void> call() => _repository.clearCredentials();
}
