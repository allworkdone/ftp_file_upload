import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ftp_credentials.dart';
import '../../domain/usecases/get_credentials_usecase.dart';
import '../../domain/usecases/save_credentials_usecase.dart';
import '../../domain/usecases/test_connection_usecase.dart';
import '../../../../core/di/injection.dart';

class AuthState {
  final FTPCredentials? credentials;
  final bool testing;
  final bool connected;
  final String? error;

  const AuthState({
    this.credentials,
    this.testing = false,
    this.connected = false,
    this.error,
  });

  AuthState copyWith({
    FTPCredentials? credentials,
    bool? testing,
    bool? connected,
    String? error,
  }) => AuthState(
        credentials: credentials ?? this.credentials,
        testing: testing ?? this.testing,
        connected: connected ?? this.connected,
        error: error,
      );
}

class AuthViewModel extends StateNotifier<AuthState> {
  final GetCredentialsUsecase _getCredentials;
  final SaveCredentialsUsecase _saveCredentials;
  final TestConnectionUsecase _testConnection;

  AuthViewModel()
      : _getCredentials = getIt<GetCredentialsUsecase>(),
        _saveCredentials = getIt<SaveCredentialsUsecase>(),
        _testConnection = getIt<TestConnectionUsecase>(),
        super(const AuthState()) {
    loadSaved();
  }

  Future<void> loadSaved() async {
    final creds = await _getCredentials();
    if (creds != null) {
      state = state.copyWith(credentials: creds);
    }
  }

  Future<void> save(FTPCredentials credentials) async {
    await _saveCredentials(credentials);
    state = state.copyWith(credentials: credentials);
  }

  Future<bool> test(FTPCredentials credentials) async {
    state = state.copyWith(testing: true, error: null);
    final ok = await _testConnection(credentials);
    state = state.copyWith(testing: false, connected: ok, error: ok ? null : 'Connection failed');
    return ok;
  }
}

final authViewModelProvider = StateNotifierProvider<AuthViewModel, AuthState>((ref) => AuthViewModel());
