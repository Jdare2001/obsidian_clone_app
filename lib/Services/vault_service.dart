import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../Models/vault.dart';
import '../Models/note.dart';
import '../Models/folder.dart';

class VaultService {
  static const String lastVaultKey = "lastVaultPath";

  // Open OS folder picker
  Future<String?> selectVaultDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return null;
    return selectedDirectory;
  }

  // Persist last vault path
  Future<void> saveLastVaultPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastVaultKey, path);
  }

  // Load last vault path
  Future<String?> getLastVaultPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(lastVaultKey);
    if (path != null && await Directory(path).exists()) return path;
    return null;
  }

  // Load vault
  Future<Vault> loadVault(String path) async {
    return Vault(rootPath: path);
  }

  Future<void> saveNote(Note note) async {
    final file = File(note.path);
    await file.writeAsString(note.content);
  }

  Future<Note> createNote(String folderPath, String title) async {
    final path = "$folderPath/$title.md";
    final file = File(path);
    await file.writeAsString("# $title\n");
    return Note(path: path, title: title, content: "# $title\n");
  }

  Future<Note> renameNote(Note note, String newTitle) async {
    final oldFile = File(note.path);
    final newPath =
        oldFile.parent.path + Platform.pathSeparator + "$newTitle.md";
    final newFile = await oldFile.rename(newPath);

    return Note(path: newFile.path, title: newTitle, content: note.content);
  }

  Future<void> deleteNote(Note note) async {
    final file = File(note.path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
