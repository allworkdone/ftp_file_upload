import 'package:hive/hive.dart';

import '../../../../shared/data/providers/hive_provider.dart';
import '../../domain/entities/ftp_credentials.dart';
import '../models/ftp_credentials_model.dart';

abstract class AuthLocalDatasource {
  Future<void> saveCredentials(FTPCredentials credentials);
  Future<FTPCredentials?> getCredentials();
}

class AuthLocalDatasourceImpl implements AuthLocalDatasource {
  final HiveProvider _hiveProvider;
  static const String _boxName = 'credentials';
  static const String _key = 'ftp_credentials';

  AuthLocalDatasourceImpl(this._hiveProvider);

  Future<Box<dynamic>> _box() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await _hiveProvider.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  @override
  Future<void> saveCredentials(FTPCredentials credentials) async {
    final box = await _box();
    final model = FTPCredentialsModel.fromEntity(credentials);
    await box.put(_key, model.toMap());
  }

  @override
  Future<FTPCredentials?> getCredentials() async {
    final box = await _box();
    final map = box.get(_key);
    if (map is Map) {
      return FTPCredentialsModel.fromMap(map);
    }
    return null;
  }
}
