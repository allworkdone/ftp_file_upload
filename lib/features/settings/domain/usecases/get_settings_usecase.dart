import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';

class GetSettingsUsecase {
  final SettingsRepository _repo;
  GetSettingsUsecase(this._repo);

  Future<AppSettings> call() => _repo.getSettings();
}

