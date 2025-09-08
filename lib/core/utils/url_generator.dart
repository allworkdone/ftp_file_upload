class UrlGenerator {
  static const String _defaultBaseUrl = 'https://project.ibartstech.com';

  String _baseUrl;

  UrlGenerator({String? baseUrl}) : _baseUrl = baseUrl ?? _defaultBaseUrl;

  /// Update the base URL
  void updateBaseUrl(String newBaseUrl) {
    _baseUrl = newBaseUrl.endsWith('/')
        ? newBaseUrl.substring(0, newBaseUrl.length - 1)
        : newBaseUrl;
  }

  /// Get current base URL
  String get baseUrl => _baseUrl;

  /// Generate download URL for uploaded file
  String generateFileUrl(String folderPath, String fileName) {
    // Clean folder path
    final cleanFolderPath = _cleanPath(folderPath);

    // Clean file name
    final cleanFileName = Uri.encodeComponent(fileName);

    // Construct URL
    if (cleanFolderPath.isEmpty) {
      return '$_baseUrl/$cleanFileName';
    }

    return '$_baseUrl/$cleanFolderPath/$cleanFileName';
  }

  /// Generate folder URL
  String generateFolderUrl(String folderPath) {
    final cleanFolderPath = _cleanPath(folderPath);

    if (cleanFolderPath.isEmpty) {
      return _baseUrl;
    }

    return '$_baseUrl/$cleanFolderPath';
  }

  /// Clean path by removing leading/trailing slashes and encoding
  String _cleanPath(String path) {
    if (path.isEmpty) return '';

    // Remove leading and trailing slashes
    String cleanPath = path;
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    if (cleanPath.endsWith('/')) {
      cleanPath = cleanPath.substring(0, cleanPath.length - 1);
    }

    // Split by / and encode each segment
    final segments = cleanPath.split('/').where((s) => s.isNotEmpty);
    final encodedSegments = segments.map((s) => Uri.encodeComponent(s));

    return encodedSegments.join('/');
  }

  /// Extract folder path from URL
  String? extractFolderPathFromUrl(String url) {
    if (!url.startsWith(_baseUrl)) return null;

    final path = url.substring(_baseUrl.length);
    if (path.isEmpty || path == '/') return '';

    // Remove leading slash
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    // Remove file name if present (assume last segment after / is file)
    final segments = cleanPath.split('/');
    if (segments.length == 1) {
      // Could be a file in root or a folder
      return '';
    }

    // Return all segments except the last one (assuming last is filename)
    return segments.take(segments.length - 1).join('/');
  }

  /// Validate if URL is from our domain
  bool isValidProjectUrl(String url) {
    return url.startsWith(_baseUrl);
  }
}
