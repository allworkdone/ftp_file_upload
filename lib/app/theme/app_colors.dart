import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryLight = Color(0xFF64B5F6);
  static const Color primaryDark = Color(0xFF1976D2);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF4CAF50);
  static const Color secondaryLight = Color(0xFF81C784);
  static const Color secondaryDark = Color(0xFF388E3C);
  
  // Accent Colors
  static const Color accent = Color(0xFFFF9800);
  static const Color accentLight = Color(0xFFFFB74D);
  static const Color accentDark = Color(0xFFF57C00);
  
  // Neutral Colors (Light Theme)
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF212121);
  static const Color onSurface = Color(0xFF424242);
  static const Color outline = Color(0xFFE0E0E0);
  
  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkOnBackground = Color(0xFFE0E0E0);
  static const Color darkOnSurface = Color(0xFFFFFFFF);
  static const Color darkOutline = Color(0xFF424242);
  
  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // FTP Status Colors
  static const Color connected = success;
  static const Color connecting = warning;
  static const Color disconnected = error;
  static const Color uploading = info;
  static const Color uploadComplete = success;
  static const Color uploadFailed = error;
  
  // File Type Colors
  static const Color folderColor = Color(0xFFFFB74D);
  static const Color imageFileColor = Color(0xFF4CAF50);
  static const Color documentFileColor = Color(0xFF2196F3);
  static const Color videoFileColor = Color(0xFF9C27B0);
  static const Color audioFileColor = Color(0xFFFF5722);
  static const Color archiveFileColor = Color(0xFF795548);
  static const Color unknownFileColor = Color(0xFF9E9E9E);
  
  // Gradient Colors
  static const Gradient primaryGradient = LinearGradient(
    colors: [primaryLight, primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient successGradient = LinearGradient(
    colors: [secondaryLight, secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient warningGradient = LinearGradient(
    colors: [accentLight, accent, accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Material Swatch for backward compatibility
  static const MaterialColor primarySwatch = MaterialColor(
    0xFF2196F3,
    <int, Color>{
      50: Color(0xFFE3F2FD),
      100: Color(0xFFBBDEFB),
      200: Color(0xFF90CAF9),
      300: Color(0xFF64B5F6),
      400: Color(0xFF42A5F5),
      500: Color(0xFF2196F3),
      600: Color(0xFF1E88E5),
      700: Color(0xFF1976D2),
      800: Color(0xFF1565C0),
      900: Color(0xFF0D47A1),
    },
  );
  
  // Opacity variations
  static Color withLowOpacity(Color color) => color.withOpacity(0.1);
  static Color withMediumOpacity(Color color) => color.withOpacity(0.5);
  static Color withHighOpacity(Color color) => color.withOpacity(0.8);
  
  // Helper methods for file type colors
  static Color getFileTypeColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'svg':
      case 'webp':
        return imageFileColor;
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
      case 'rtf':
        return documentFileColor;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
      case 'wmv':
        return videoFileColor;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return audioFileColor;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return archiveFileColor;
      default:
        return unknownFileColor;
    }
  }
}