import 'folder.dart';
import 'dart:io';

class Vault {
  final String rootPath;
  late Folder rootFolder;

  Vault({required this.rootPath}) {
    rootFolder = Folder(
      name: Directory(rootPath).uri.pathSegments.last,
      path: rootPath,
    );
    // Optionally: load subfolders and notes
  }
}
