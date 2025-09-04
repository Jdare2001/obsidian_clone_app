import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../Models/note.dart';
import '../Models/vault.dart';
import '../Models/folder.dart';
import '../Services/vault_service.dart';

import 'package:file_picker/file_picker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VaultService vaultService = VaultService();

  bool showSidebar = true;
  bool previewMode = false;

  Map<String, dynamic>? rootFolder;
  Map<String, dynamic>? currentFolder;
  Map<String, dynamic>? selectedNote;

  @override
  void initState() {
    super.initState();
    _loadLastVault();
  }

  Future<void> _loadLastVault() async {
    final path = await vaultService.getLastVaultPath();
    if (path != null) {
      final folderData = await _buildFolderMap(path);
      setState(() {
        rootFolder = folderData;
        currentFolder = rootFolder;
      });
    }
  }

  Future<Map<String, dynamic>> _buildFolderMap(String path) async {
    Directory dir = Directory(path);
    List<Map<String, dynamic>> subfolders = [];
    List<Map<String, dynamic>> notes = [];

    for (var entity in dir.listSync()) {
      if (entity is Directory) {
        subfolders.add(await _buildFolderMap(entity.path));
      } else if (entity is File && entity.path.endsWith(".txt")) {
        notes.add({
          "title": entity.uri.pathSegments.last.replaceAll(".txt", ""),
          "content": await entity.readAsString(),
          "path": entity.path,
        });
      }
    }

    // Use the last non-empty path segment as folder name, fallback to splitting by path separator.
    String folderName = dir.uri.pathSegments.isNotEmpty
        ? dir.uri.pathSegments.lastWhere(
            (s) => s.isNotEmpty,
            orElse: () => dir.path.split(Platform.pathSeparator).last,
          )
        : dir.path.split(Platform.pathSeparator).last;

    return {
      "name": folderName,
      "path": dir.path,
      "subfolders": subfolders,
      "notes": notes,
    };
  }

  Future<void> _openBaseVault() async {
    final path = await vaultService.selectVaultDirectory();
    if (path != null) {
      await vaultService.saveLastVaultPath(path);
      final folderData = await _buildFolderMap(path);
      setState(() {
        rootFolder = folderData;
        currentFolder = rootFolder;
        selectedNote = null;
      });
    }
  }

  Future<bool> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;
    // For Android 11+ we may need MANAGE_EXTERNAL_STORAGE
    if (await Permission.storage.isGranted) return true;
    if (await Permission.storage.request().isGranted) return true;
    // Try requesting manage external storage (Android 11+)
    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await Permission.manageExternalStorage.request().isGranted) return true;
    return false;
  }

  Future<void> _createNewFolder() async {
    if (currentFolder == null) return;

    if (!await _ensureStoragePermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Storage permission required to create folders."),
        ),
      );
      return;
    }

    final controller = TextEditingController();
    final folderName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text("New Folder", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Folder name",
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Create"),
          ),
        ],
      ),
    );

    if (folderName != null && folderName.isNotEmpty) {
      final newPath = "${currentFolder!["path"]}/$folderName";
      final dir = Directory(newPath);
      if (!await dir.exists()) await dir.create();

      setState(() {
        currentFolder!["subfolders"].add({
          "name": folderName,
          "path": newPath,
          "subfolders": [],
          "notes": [],
        });
      });
    }
  }

  Future<void> _createNewNote() async {
    if (currentFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a folder first.")),
      );
      return;
    }

    if (!await _ensureStoragePermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Storage permission required to create notes."),
        ),
      );
      return;
    }

    final controller = TextEditingController();
    final noteName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text("New Note", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Note title",
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Create"),
          ),
        ],
      ),
    );

    if (noteName != null && noteName.isNotEmpty) {
      final notePath = "${currentFolder!["path"]}/$noteName.txt";
      final file = File(notePath);
      await file.writeAsString("");

      setState(() {
        final newNote = {"title": noteName, "content": "", "path": notePath};
        currentFolder!["notes"].add(newNote);
        selectedNote = newNote;
      });
    }
  }

  Widget buildFolderTree(Map<String, dynamic> folder) {
    return ExpansionTile(
      key: PageStorageKey(folder["path"]),
      title: InkWell(
        onTap: () {
          setState(() {
            currentFolder = folder;
            selectedNote = null;
          });
        },
        child: Text(
          folder["name"],
          style: TextStyle(
            color: currentFolder == folder
                ? Colors.deepPurpleAccent
                : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      children: [
        // Notes in this folder
        ...List<Widget>.from(
          folder["notes"].map<Widget>(
            (note) => ListTile(
              title: Text(
                note["title"],
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF2D2D2D),
                      title: const Text(
                        "Delete Note?",
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        "This will permanently delete the note.",
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                  );

                  if (confirm != true) return;

                  try {
                    final file = File(note["path"]);
                    if (await file.exists()) await file.delete();
                  } catch (_) {}

                  setState(() {
                    folder["notes"].remove(note);
                    if (selectedNote != null &&
                        selectedNote!["path"] == note["path"]) {
                      selectedNote = null;
                    }
                  });
                },
              ),
              onTap: () {
                setState(() {
                  selectedNote = note;
                });
              },
            ),
          ),
        ),
        // Subfolders (nested)
        ...List<Widget>.from(
          folder["subfolders"].map<Widget>((sub) => buildFolderTree(sub)),
        ),
      ],
      initiallyExpanded: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          if (showSidebar)
            Container(
              width: 260,
              color: const Color(0xFF2D2D2D),
              child: Padding(
                padding: const EdgeInsets.only(top: 50),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.folder_open,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        "Open Base Vault",
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: _openBaseVault,
                    ),
                    if (rootFolder != null)
                      ListTile(
                        leading: const Icon(
                          Icons.create_new_folder,
                          color: Colors.white70,
                        ),
                        title: const Text(
                          "New Folder",
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: _createNewFolder,
                      ),
                    if (rootFolder != null)
                      ListTile(
                        leading: const Icon(
                          Icons.note_add,
                          color: Colors.white70,
                        ),
                        title: const Text(
                          "New Note",
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: _createNewNote,
                      ),
                    Expanded(
                      child: rootFolder == null
                          ? const Center(
                              child: Text(
                                "No vault open",
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : ListView(children: [buildFolderTree(rootFolder!)]),
                    ),
                  ],
                ),
              ),
            ),
          if (showSidebar) Container(width: 1, color: Colors.black),
          Expanded(
            child: Column(
              children: [
                Container(
                  color: const Color(0xFF2D2D2D),
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              showSidebar ? Icons.menu_open : Icons.menu,
                            ),
                            color: Colors.white70,
                            onPressed: () =>
                                setState(() => showSidebar = !showSidebar),
                          ),
                          Expanded(
                            child: Text(
                              selectedNote?["title"] ?? "No note selected",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              previewMode ? Icons.edit : Icons.remove_red_eye,
                              color: Colors.white70,
                            ),
                            onPressed: () =>
                                setState(() => previewMode = !previewMode),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: selectedNote == null
                      ? const Center(
                          child: Text(
                            "Select or create a note",
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : previewMode
                      ? Markdown(
                          data: selectedNote!["content"],
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(
                                Theme.of(context),
                              ).copyWith(
                                p: const TextStyle(color: Colors.white70),
                                h1: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        )
                      : TextField(
                          controller: TextEditingController(
                            text: selectedNote!["content"],
                          ),
                          expands: true,
                          maxLines: null,
                          style: const TextStyle(color: Colors.white70),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(12),
                          ),
                          onChanged: (val) {
                            selectedNote!["content"] = val;
                            File(selectedNote!["path"]).writeAsString(val);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
