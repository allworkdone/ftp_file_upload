import 'package:file_upload/features/authentication/domain/usecases/clear_credentials_usecase.dart';
import 'package:file_upload/features/file_manager/domain/usecases/delete_folder_usecase.dart';
import 'package:file_upload/features/file_manager/domain/usecases/download_file_usercase.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../network/network_info.dart';
import '../network/dio_client.dart';
import '../utils/app_logger.dart';
import '../utils/file_utils.dart';
import '../utils/permission_utils.dart';
import '../utils/url_generator.dart';
import '../../app/router/app_router.dart';
import '../../shared/data/providers/hive_provider.dart';
import '../../shared/data/providers/shared_preferences_provider.dart';
import '../services/notification_service.dart';

// Feature imports
import '../../features/authentication/data/datasources/auth_local_datasource.dart';
import '../../features/authentication/data/datasources/auth_remote_datasource.dart';
import '../../features/authentication/data/repositories/auth_repository_impl.dart';
import '../../features/authentication/domain/repositories/auth_repository.dart';
import '../../features/authentication/domain/usecases/save_credentials_usecase.dart';
import '../../features/authentication/domain/usecases/get_credentials_usecase.dart';
import '../../features/authentication/domain/usecases/test_connection_usecase.dart';

import '../../features/file_manager/data/datasources/ftp_datasource.dart';
import '../../features/file_manager/data/datasources/local_file_datasource.dart';
import '../../features/file_manager/data/repositories/file_manager_repository_impl.dart';
import '../../features/file_manager/domain/repositories/file_manager_repository.dart';
import '../../features/file_manager/domain/usecases/get_folders_usecase.dart';
import '../../features/file_manager/domain/usecases/create_folder_usecase.dart';
import '../../features/file_manager/domain/usecases/upload_file_usecase.dart';
import '../../features/file_manager/domain/usecases/delete_file_usecase.dart';
import '../../features/file_manager/domain/usecases/generate_link_usecase.dart';
import '../../features/file_manager/domain/usecases/get_files_usecase.dart';
import '../../features/file_manager/domain/usecases/rename_file_usecase.dart';
import '../../features/file_manager/domain/usecases/rename_folder_usecase.dart';

// Upload history
import '../../features/upload_history/data/datasources/upload_history_local_datasource.dart';
import '../../features/upload_history/data/repositories/upload_history_repository_impl.dart';
import '../../features/upload_history/domain/repositories/upload_history_repository.dart';
import '../../features/upload_history/domain/usecases/get_upload_history_usecase.dart';
import '../../features/upload_history/domain/usecases/save_upload_record_usecase.dart';
import '../../features/upload_history/domain/usecases/clear_history_usecase.dart';

// Settings
import '../../features/settings/data/datasources/settings_local_datasource.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/domain/usecases/get_settings_usecase.dart';
import '../../features/settings/domain/usecases/update_settings_usecase.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() async {
  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  final connectivity = Connectivity();
  getIt.registerSingleton<Connectivity>(connectivity);

  // Hive boxes initialization
  await _initializeHiveBoxes();

  // Core services
  getIt.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(getIt<Connectivity>()),
  );

  getIt.registerLazySingleton<DioClient>(() => DioClient());

  getIt.registerLazySingleton<FileUtils>(() => FileUtils());

  getIt.registerLazySingleton<PermissionUtils>(() => PermissionUtils());

  getIt.registerLazySingleton<UrlGenerator>(() => UrlGenerator());

  getIt.registerLazySingleton<AppRouter>(() => AppRouter());

  // Data providers
  getIt.registerLazySingleton<HiveProvider>(() => HiveProvider());

  getIt.registerLazySingleton<SharedPreferencesProvider>(
    () => SharedPreferencesProvider(getIt<SharedPreferences>()),
  );

  // Authentication feature
  getIt.registerLazySingleton<AuthLocalDatasource>(
    () => AuthLocalDatasourceImpl(getIt<HiveProvider>()),
  );

  getIt.registerLazySingleton<AuthRemoteDatasource>(
    () => AuthRemoteDatasourceImpl(),
  );

  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      localDataSource: getIt<AuthLocalDatasource>(),
      remoteDataSource: getIt<AuthRemoteDatasource>(),
      networkInfo: getIt<NetworkInfo>(),
    ),
  );

  getIt.registerLazySingleton<SaveCredentialsUsecase>(
    () => SaveCredentialsUsecase(getIt<AuthRepository>()),
  );

  getIt.registerLazySingleton<GetCredentialsUsecase>(
    () => GetCredentialsUsecase(getIt<AuthRepository>()),
  );

  getIt.registerLazySingleton<TestConnectionUsecase>(
    () => TestConnectionUsecase(getIt<AuthRepository>()),
  );

  // File Manager feature
  getIt.registerLazySingleton<FTPDatasource>(() => FTPDatasourceImpl());

  getIt.registerLazySingleton<LocalFileDatasource>(
    () => LocalFileDatasourceImpl(getIt<FileUtils>()),
  );

  getIt.registerLazySingleton<FileManagerRepository>(
    () => FileManagerRepositoryImpl(
      ftpDatasource: getIt<FTPDatasource>(),
      localFileDatasource: getIt<LocalFileDatasource>(),
      networkInfo: getIt<NetworkInfo>(),
    ),
  );

  getIt.registerLazySingleton<GetFoldersUsecase>(
    () => GetFoldersUsecase(getIt<FileManagerRepository>()),
  );

  getIt.registerLazySingleton<GetFilesUsecase>(
    () => GetFilesUsecase(getIt<FileManagerRepository>()),
  );

  getIt.registerLazySingleton<CreateFolderUsecase>(
    () => CreateFolderUsecase(getIt<FileManagerRepository>()),
  );

  getIt.registerLazySingleton<UploadFileUsecase>(
    () => UploadFileUsecase(getIt<FileManagerRepository>()),
  );

  getIt.registerLazySingleton<DeleteFileUsecase>(
    () => DeleteFileUsecase(getIt<FileManagerRepository>()),
  );

  getIt.registerLazySingleton<GenerateLinkUsecase>(
    () => GenerateLinkUsecase(
      getIt<UrlGenerator>(),
      getIt<GetSettingsUsecase>(),
    ),
  );

  // Upload History feature
  getIt.registerLazySingleton<UploadHistoryLocalDatasource>(
    () => UploadHistoryLocalDatasourceImpl(getIt<HiveProvider>()),
  );

  getIt.registerLazySingleton<UploadHistoryRepository>(
    () => UploadHistoryRepositoryImpl(getIt<UploadHistoryLocalDatasource>()),
  );

  getIt.registerLazySingleton<GetUploadHistoryUsecase>(
    () => GetUploadHistoryUsecase(getIt<UploadHistoryRepository>()),
  );

  getIt.registerLazySingleton<SaveUploadRecordUsecase>(
    () => SaveUploadRecordUsecase(getIt<UploadHistoryRepository>()),
  );

  getIt.registerLazySingleton<ClearHistoryUsecase>(
    () => ClearHistoryUsecase(getIt<UploadHistoryRepository>()),
  );

  // Settings feature
  getIt.registerLazySingleton<SettingsLocalDatasource>(
    () => SettingsLocalDatasourceImpl(getIt<SharedPreferencesProvider>()),
  );

  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(getIt<SettingsLocalDatasource>()),
  );

  getIt.registerLazySingleton<GetSettingsUsecase>(
    () => GetSettingsUsecase(getIt<SettingsRepository>()),
  );

  getIt.registerLazySingleton<UpdateSettingsUsecase>(
    () => UpdateSettingsUsecase(getIt<SettingsRepository>()),
  );

  getIt.registerLazySingleton<ClearCredentialsUsecase>(
    () => ClearCredentialsUsecase(getIt<AuthRepository>()),
  );

  getIt.registerLazySingleton<DeleteFolderUsecase>(
    () => DeleteFolderUsecase(getIt<FileManagerRepository>()),
  );

  getIt.registerLazySingleton<DownloadFileUsecase>(
    () => DownloadFileUsecase(getIt<FileManagerRepository>()),
  );

  getIt.registerLazySingleton<RenameFileUsecase>(
    () => RenameFileUsecase(getIt<FileManagerRepository>()),
  );

  getIt.registerLazySingleton<RenameFolderUsecase>(
    () => RenameFolderUsecase(getIt<FileManagerRepository>()),
  );

  // Initialize and register notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  getIt.registerSingleton<NotificationService>(notificationService);

  AppLogger.info('Dependency injection setup completed');
}

Future<void> _initializeHiveBoxes() async {
  // Register Hive adapters here if needed
  // Hive.registerAdapter(FTPCredentialsModelAdapter());

  // Open required boxes
  await Hive.openBox('credentials');
  await Hive.openBox('upload_history');
  await Hive.openBox('settings');

  AppLogger.info('Hive boxes initialized');
}
