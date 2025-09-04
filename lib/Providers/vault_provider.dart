import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Models/note.dart';
import '../Models/vault.dart';
import '../Services/vault_service.dart';

final vaultProvider = StateNotifierProvider<VaultNotifier, Vault?>((ref) {
  return VaultNotifier(VaultService());
});

class VaultNotifier extends StateNotifier<Vault?> {
  final VaultService _service;
  VaultNotifier(this._service) : super(null);

  Future<void> loadVault(String path) async {
    state = await _service.loadVault(path);
  }

  Future<void> saveNote(Note note) async {
    await _service.saveNote(note);
    await loadVault(state!.rootPath); // refresh
  }
}
