import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';

class UpdateSettingsUsecase {
  final SettingsRepository _repo;
  UpdateSettingsUsecase(this._repo);

  Future<void> call(AppSettings s) => _repo.updateSettings(s);
}

