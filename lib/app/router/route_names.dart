class RouteNames {
  // Authentication Routes
  static const String login = '/login';
  static const String connectionSetup = '/connection-setup';
  
  // Main App Routes
  static const String fileManager = '/file-manager';
  static const String folderBrowser = 'folder';
  static const String upload = 'upload';
  
  // Feature Routes
  static const String uploadHistory = '/upload-history';
  static const String settings = '/settings';
  
  static const String fileViewer = 'viewer';

  // Utility methods
  static String folderBrowserPath(String folderPath) =>
      '/file-manager/folder/${Uri.encodeComponent(folderPath)}';
  
  static String uploadPath({String? folderPath}) {
    final path = '/file-manager/upload';
    if (folderPath != null && folderPath.isNotEmpty) {
      return '$path?folderPath=${Uri.encodeQueryComponent(folderPath)}';
    }
    return path;
  }

  static String fileViewerPath(String filePath, String fileName) {
    return '/file-manager/viewer?path=${Uri.encodeQueryComponent(filePath)}&name=${Uri.encodeQueryComponent(fileName)}';
  }
}