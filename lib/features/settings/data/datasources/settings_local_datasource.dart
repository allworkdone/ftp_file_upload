import '../../../../shared/data/providers/shared_preferences_provider.dart';
import '../../domain/entities/app_settings.dart' as domain;

abstract class SettingsLocalDatasource {
  Future<domain.AppSettings> getSettings();
  Future<void> updateSettings(domain.AppSettings settings);
}

class SettingsLocalDatasourceImpl implements SettingsLocalDatasource {
  final SharedPreferencesProvider _prefs;
  SettingsLocalDatasourceImpl(this._prefs);

  static const _prefix = 'settings_';

  @override
  Future<domain.AppSettings> getSettings() async {
    final themeIndex = _prefs.getInt('${_prefix}themeMode') ?? 2; // system
    return domain.AppSettings(
      themeMode: domain.ThemeMode.values[themeIndex],
      enableNotifications: _prefs.getBool('${_prefix}enableNotifications') ?? true,
      autoDeleteAfterUpload: _prefs.getBool('${_prefix}autoDeleteAfterUpload') ?? false,
      maxConcurrentUploads: _prefs.getInt('${_prefix}maxConcurrentUploads') ?? 3,
      uploadQuality: domain.UploadQuality.values[_prefs.getInt('${_prefix}uploadQuality') ?? domain.UploadQuality.original.index],
      compressImages: _prefs.getBool('${_prefix}compressImages') ?? false,
      keepUploadHistory: _prefs.getBool('${_prefix}keepUploadHistory') ?? true,
      maxHistoryDays: _prefs.getInt('${_prefix}maxHistoryDays') ?? 30,
      requireWifiForUpload: _prefs.getBool('${_prefix}requireWifiForUpload') ?? false,
      enableAutoBackup: _prefs.getBool('${_prefix}enableAutoBackup') ?? false,
    );
  }

  @override
  Future<void> updateSettings(domain.AppSettings s) async {
    await _prefs.setInt('${_prefix}themeMode', s.themeMode.index);
    await _prefs.setBool('${_prefix}enableNotifications', s.enableNotifications);
    await _prefs.setBool('${_prefix}autoDeleteAfterUpload', s.autoDeleteAfterUpload);
    await _prefs.setInt('${_prefix}maxConcurrentUploads', s.maxConcurrentUploads);
    await _prefs.setInt('${_prefix}uploadQuality', s.uploadQuality.index);
    await _prefs.setBool('${_prefix}compressImages', s.compressImages);
    await _prefs.setBool('${_prefix}keepUploadHistory', s.keepUploadHistory);
    await _prefs.setInt('${_prefix}maxHistoryDays', s.maxHistoryDays);
    await _prefs.setBool('${_prefix}requireWifiForUpload', s.requireWifiForUpload);
    await _prefs.setBool('${_prefix}enableAutoBackup', s.enableAutoBackup);
  }
}

