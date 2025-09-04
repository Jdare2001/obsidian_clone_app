import 'note.dart';

class Folder {
  final String name;
  final String path;
  List<Folder> subfolders;
  List<dynamic> notes;

  Folder({
    required this.name,
    required this.path,
    List<Folder>? subfolders,
    List<dynamic>? notes,
  }) : subfolders = subfolders ?? [],
       notes = notes ?? [];
}
