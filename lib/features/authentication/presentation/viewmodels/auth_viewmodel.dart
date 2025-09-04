// lib/features/authentication/presentation/viewmodels/auth_viewmodel.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ftp_credentials.dart';
import '../../domain/usecases/get_credentials_usecase.dart';
import '../../domain/usecases/save_credentials_usecase.dart';
import '../../domain/usecases/test_connection_usecase.dart';
import '../../domain/usecases/clear_credentials_usecase.dart'; // NEW
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
  }) =>
      AuthState(
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
  final ClearCredentialsUsecase _clearCredentials; // NEW

  AuthViewModel()
      : _getCredentials = getIt<GetCredentialsUsecase>(),
        _saveCredentials = getIt<SaveCredentialsUsecase>(),
        _testConnection = getIt<TestConnectionUsecase>(),
        _clearCredentials = getIt<ClearCredentialsUsecase>(), // NEW
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
    state = state.copyWith(
        testing: false, connected: ok, error: ok ? null : 'Connection failed');
    return ok;
  }

  // NEW: Clear saved credentials
  Future<void> clearCredentials() async {
    await _clearCredentials();
    state = state.copyWith(credentials: null, connected: false, error: null);
  }

  // NEW: Logout method
  void logout() {
    state = state.copyWith(credentials: null, connected: false, error: null);
  }
}

final authViewModelProvider =
    StateNotifierProvider<AuthViewModel, AuthState>((ref) => AuthViewModel());
