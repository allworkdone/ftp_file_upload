extension StringExtensions on String {
  bool get isNullOrEmpty => trim().isEmpty;
  String get sanitizePath => replaceAll(RegExp(r"/+"), '/');
}
