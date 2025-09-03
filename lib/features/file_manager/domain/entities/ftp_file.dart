// features/file_manager/domain/entities/ftp_file.dart
import 'package:equatable/equatable.dart';

enum FTPFileType { file, directory }

class FTPFile extends Equatable {
  final String name;
  final String path;
  final FTPFileType type;
  final int size;
  final DateTime? modifiedDate;
  final String? extension;

  const FTPFile({
    required this.name,
    required this.path,
    required this.type,
    this.size = 0,
    this.modifiedDate,
    this.extension,
  });

  FTPFile copyWith({
    String? name,
    String? path,
    FTPFileType? type,
    int? size,
    DateTime? modifiedDate,
    String? extension,
  }) {
    return FTPFile(
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      size: size ?? this.size,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      extension: extension ?? this.extension,
    );
  }

  bool get isDirectory => type == FTPFileType.directory;
  bool get isFile => type == FTPFileType.file;

  String get fullPath {
    if (path.isEmpty) return name;
    if (path.endsWith('/')) return '$path$name';
    return '$path/$name';
  }

  @override
  List<Object?> get props => [name, path, type, size, modifiedDate, extension];
}
