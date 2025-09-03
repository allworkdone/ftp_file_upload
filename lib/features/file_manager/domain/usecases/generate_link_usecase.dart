import '../../../../core/utils/url_generator.dart';

class GenerateLinkUsecase {
  final UrlGenerator _generator;
  GenerateLinkUsecase(this._generator);

  String fileUrl(String folderPath, String fileName) => _generator.generateFileUrl(folderPath, fileName);
  String folderUrl(String folderPath) => _generator.generateFolderUrl(folderPath);
}
