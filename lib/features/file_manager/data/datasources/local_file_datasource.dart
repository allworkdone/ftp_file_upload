import 'package:file_picker/file_picker.dart';

import '../../../../core/utils/file_utils.dart';

abstract class LocalFileDatasource {
  Future<PlatformFile?> pickSingleFile();
}

class LocalFileDatasourceImpl implements LocalFileDatasource {
  final FileUtils _fileUtils;
  LocalFileDatasourceImpl(this._fileUtils);

  @override
  Future<PlatformFile?> pickSingleFile() => _fileUtils.pickSingleFile();
}
