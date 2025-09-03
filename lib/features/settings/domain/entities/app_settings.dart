import 'package:equatable/equatable.dart';

enum ThemeMode { light, dark, system }

enum UploadQuality { low, medium, high, original }

class AppSettings extends Equatable {
  final ThemeMode themeMode;
  final bool enableNotifications;
  final bool autoDeleteAfterUpload;
  final int maxConcurrentUploads;
  final UploadQuality uploadQuality;
  final bool compressImages;
  final bool keepUploadHistory;
  final int maxHistoryDays;
  final bool requireWifiForUpload;
  final bool enableAutoBackup;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.enableNotifications = true,
    this.autoDeleteAfterUpload = false,
    this.maxConcurrentUploads = 3,
    this.uploadQuality = UploadQuality.original,
    this.compressImages = false,
    this.keepUploadHistory = true,
    this.maxHistoryDays = 30,
    this.requireWifiForUpload = false,
    this.enableAutoBackup = false,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? enableNotifications,
    bool? autoDeleteAfterUpload,
    int? maxConcurrentUploads,
    UploadQuality? uploadQuality,
    bool? compressImages,
    bool? keepUploadHistory,
    int? maxHistoryDays,
    bool? requireWifiForUpload,
    bool? enableAutoBackup,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      autoDeleteAfterUpload:
          autoDeleteAfterUpload ?? this.autoDeleteAfterUpload,
      maxConcurrentUploads: maxConcurrentUploads ?? this.maxConcurrentUploads,
      uploadQuality: uploadQuality ?? this.uploadQuality,
      compressImages: compressImages ?? this.compressImages,
      keepUploadHistory: keepUploadHistory ?? this.keepUploadHistory,
      maxHistoryDays: maxHistoryDays ?? this.maxHistoryDays,
      requireWifiForUpload: requireWifiForUpload ?? this.requireWifiForUpload,
      enableAutoBackup: enableAutoBackup ?? this.enableAutoBackup,
    );
  }

  @override
  List<Object?> get props => [
    themeMode,
    enableNotifications,
    autoDeleteAfterUpload,
    maxConcurrentUploads,
    uploadQuality,
    compressImages,
    keepUploadHistory,
    maxHistoryDays,
    requireWifiForUpload,
    enableAutoBackup,
  ];
}
