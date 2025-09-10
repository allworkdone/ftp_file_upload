class ProgressUtils {
  static String getProgressText(double progress) {
    if (progress < 0.05) return 'Initializing download...';
    if (progress < 0.1) return 'Requesting permissions...';
    if (progress < 0.2) return 'Connecting to server...';
    if (progress < 0.3) return 'Authenticating...';
    if (progress < 0.8) return 'Downloading file...';
    if (progress < 0.9) return 'Saving to device...';
    if (progress < 0.95) return 'Finalizing...';
    if (progress < 1.0) return 'Almost done...';
    return 'Download complete!';
  }

  static String getDownloadStats(int fileSize, double progress) {
    if (fileSize <= 0 || progress <= 0.1) return '';

    final remainingProgress = 1.0 - progress;
    final estimatedTotalTime = 10; // Simplified estimate
    final remainingTime = (estimatedTotalTime * remainingProgress).toInt();

    if (remainingTime > 60) {
      final minutes = (remainingTime / 60).ceil();
      return 'About ${minutes}m remaining';
    } else if (remainingTime > 0) {
      return 'About ${remainingTime}s remaining';
    }
    return 'Finishing up...';
  }
}
