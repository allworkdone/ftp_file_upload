import 'package:flutter/material.dart';

class AppColors {
  // ================ PRIMARY PURPLE COLORS ================
  // Deep Purple as the main brand color (Powerful & Professional)
  static const Color primary = Color(0xFF673AB7);
  static const Color primaryLight = Color(0xFF9A67EA);
  static const Color primaryDark = Color(0xFF4A148C);

  // ================ SECONDARY COLORS ================
  // Teal as a complementary accent (Modern & Fresh)
  static const Color secondary = Color(0xFF009688);
  static const Color secondaryLight = Color(0xFF52C7B8);
  static const Color secondaryDark = Color(0xFF00675B);

  // ================ ACCENT COLORS ================
  // Amber for attention-grabbing elements (Uploads, Actions)
  static const Color accent = Color(0xFFFFC107);
  static const Color accentLight = Color(0xFFFFECB3);
  static const Color accentDark = Color(0xFFFFA000);

  // ================ NEUTRAL COLORS (Light Theme) ================
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF212121);
  static const Color onSurface = Color(0xFF424242);
  static const Color outline = Color(0xFFEEEEEE);

  // ================ DARK THEME COLORS ================
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkOnBackground = Color(0xFFE0E0E0);
  static const Color darkOnSurface = Color(0xFFFFFFFF);
  static const Color darkOutline = Color(0xFF424242);

  // ================ STATUS COLORS ================
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // ================ FTP STATUS COLORS ================
  static const Color connected = success;
  static const Color connecting = warning;
  static const Color disconnected = error;
  static const Color uploading = primaryLight; // Purple accent for uploads
  static const Color uploadComplete = success;
  static const Color uploadFailed = error;

  // ================ FILE TYPE COLORS ================
  static const Color folderColor = Color(0xFFFFB74D); // Kept for consistency
  static const Color imageFileColor = Color(0xFF4CAF50); // Green
  static const Color documentFileColor = Color(0xFF2196F3); // Blue
  static const Color videoFileColor = Color(0xFF9C27B0); // Deep Purple
  static const Color audioFileColor = Color(0xFFFF5722); // Deep Orange
  static const Color archiveFileColor = Color(0xFF795548); // Brown
  static const Color unknownFileColor = Color(0xFF9E9E9E); // Grey

  // ================ PURPLE-BASED GRADIENTS ================
  static const Gradient primaryGradient = LinearGradient(
    colors: [primaryLight, primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient secondaryGradient = LinearGradient(
    colors: [secondaryLight, secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient accentGradient = LinearGradient(
    colors: [accentLight, accent, accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ================ MATERIAL COLOR SWATCH ================
  // Creates a MaterialColor swatch from the primary purple
  static const MaterialColor primarySwatch = MaterialColor(
    0xFF673AB7, // Primary value
    <int, Color>{
      50: Color(0xFFF3E5F5), // Lightest
      100: Color(0xFFE1BEE7),
      200: Color(0xFFCE93D8),
      300: Color(0xFFBA68C8),
      400: Color(0xFFAB47BC),
      500: Color(0xFF9C27B0), // Primary
      600: Color(0xFF8E24AA),
      700: Color(0xFF7B1FA2),
      800: Color(0xFF6A1B9A),
      900: Color(0xFF4A148C), // Darkest
    },
  );

  // ================ OPACITY VARIATIONS ================
  static Color withLowOpacity(Color color) =>
      color.withAlpha((0.1 * 255).round());
  static Color withMediumOpacity(Color color) =>
      color.withAlpha((0.5 * 255).round());
  static Color withHighOpacity(Color color) =>
      color.withAlpha((0.8 * 255).round());

  // ================ THEME DATA ================
  // Light Theme
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: primary,
          primaryContainer: primaryLight,
          secondary: secondary,
          secondaryContainer: secondaryLight,
          surface: surface,
          background: background,
          error: error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: onSurface,
          onBackground: onBackground,
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
        ),
      );

  // Dark Theme
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: primaryLight,
          primaryContainer: primaryDark,
          secondary: secondaryLight,
          secondaryContainer: secondaryDark,
          surface: darkSurface,
          background: darkBackground,
          error: error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: darkOnSurface,
          onBackground: darkOnBackground,
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkSurface,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryLight,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: darkOutline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryLight, width: 2),
          ),
        ),
      );

  // ================ HELPER METHODS ================
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
