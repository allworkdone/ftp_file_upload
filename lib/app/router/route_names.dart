class RouteNames {
  // Authentication Routes
  static const String login = '/login';
  static const String connectionSetup = '/connection-setup';
  
  // Main App Routes
  static const String fileManager = '/file-manager';
  static const String upload = 'upload';
  
  // Feature Routes
  static const String uploadHistory = '/upload-history';
  static const String settings = '/settings';
  
  // Utility methods
  static String fileManagerPath({String? path}) {
    final basePath = '/file-manager';
    if (path != null && path.isNotEmpty && path != '/') {
      return '$basePath?path=${Uri.encodeComponent(path)}';
    }
    return basePath;
  }
  
  static String uploadPath({String? folderPath}) {
    final path = '/file-manager/upload';
    if (folderPath != null && folderPath.isNotEmpty) {
      return '$path?folderPath=${Uri.encodeComponent(folderPath)}';
    }
    return path;
  }
}
