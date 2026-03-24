import "dart:convert";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

@lazySingleton
class ClosedProjectsStorage {
  static const _storageKey = "closed_project_ids";
  final SecureStorage _storage;

  ClosedProjectsStorage(SecureStorage storage) : _storage = storage;

  Future<Set<String>> getClosedProjectIds() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return {};
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<String>().toSet();
  }

  Future<void> closeProject(String id) async {
    final ids = await getClosedProjectIds();
    ids.add(id);
    await _storage.write(key: _storageKey, value: jsonEncode(ids.toList()));
  }

  Future<void> openProject(String id) async {
    final ids = await getClosedProjectIds();
    if (!ids.remove(id)) return;
    await _storage.write(key: _storageKey, value: jsonEncode(ids.toList()));
  }

  Future<bool> isProjectClosed(String id) async {
    final ids = await getClosedProjectIds();
    return ids.contains(id);
  }
}
