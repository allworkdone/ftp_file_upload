extension FileNameExt on String {
  String get fileName {
    final parts = split('/');
    return parts.isEmpty ? this : parts.last;
  }
}
