import '../../../../core/utils/url_generator.dart';
import '../../../settings/domain/usecases/get_settings_usecase.dart';

class GenerateLinkUsecase {
  final UrlGenerator _generator;
  final GetSettingsUsecase _getSettingsUsecase;

  GenerateLinkUsecase(this._generator, this._getSettingsUsecase);

  Future<String> fileUrl(String folderPath, String fileName) async {
    await _updateGeneratorBaseUrl();
    return _generator.generateFileUrl(folderPath, fileName);
  }

  Future<String> folderUrl(String folderPath) async {
    await _updateGeneratorBaseUrl();
    return _generator.generateFolderUrl(folderPath);
  }

  /// Update the generator with current base URL from settings
  Future<void> _updateGeneratorBaseUrl() async {
    final settings = await _getSettingsUsecase();
    _generator.updateBaseUrl(settings.baseDownloadUrl);
  }
}
