import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_datasource.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDatasource _local;
  SettingsRepositoryImpl(this._local);

  @override
  Future<AppSettings> getSettings() => _local.getSettings();

  @override
  Future<void> updateSettings(AppSettings settings) => _local.updateSettings(settings);
}

