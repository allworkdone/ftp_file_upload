import 'package:equatable/equatable.dart';
import 'package:file_upload/features/file_manager/domain/entities/ftp_file.dart';

class FTPFolder extends Equatable {
  final String name;
  final String path;
  final List<FTPFile> files;
  final List<FTPFolder> subFolders;
  final DateTime? createdDate;

  const FTPFolder({
    required this.name,
    required this.path,
    this.files = const [],
    this.subFolders = const [],
    this.createdDate,
  });

  FTPFolder copyWith({
    String? name,
    String? path,
    List<FTPFile>? files,
    List<FTPFolder>? subFolders,
    DateTime? createdDate,
  }) {
    return FTPFolder(
      name: name ?? this.name,
      path: path ?? this.path,
      files: files ?? this.files,
      subFolders: subFolders ?? this.subFolders,
      createdDate: createdDate ?? this.createdDate,
    );
  }

  String get fullPath {
    // The path property already contains the full path to the folder
    // No need to concatenate with name
    return path;
  }

  int get totalFiles => files.length;
  int get totalSubFolders => subFolders.length;
  bool get isEmpty => files.isEmpty && subFolders.isEmpty;

  @override
  List<Object?> get props => [name, path, files, subFolders, createdDate];
}
