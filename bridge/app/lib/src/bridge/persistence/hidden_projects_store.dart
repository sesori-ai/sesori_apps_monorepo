import "dart:convert";
import "dart:io";

import "package:meta/meta.dart";

const _hiddenProjectsFileName = "hidden_projects.json";

/// Persists hidden project ids to ~/.config/sesori-bridge/hidden_projects.json.
class HiddenProjectsStore {
  final File _file;

  HiddenProjectsStore() : _file = File(_defaultPath());

  @visibleForTesting
  HiddenProjectsStore.withFile({required File file}) : _file = file;

  Future<Set<String>> getHiddenProjectIds() async {
    final decoded = await _readFileJson();
    final ids = switch (decoded) {
      final List<dynamic> list => list,
      final Map<String, dynamic> map => map["hiddenProjectIds"] as List<dynamic>? ?? const [],
      _ => const <dynamic>[],
    };

    return ids.whereType<String>().toSet();
  }

  Future<void> hideProject({required String projectId}) async {
    final hidden = await getHiddenProjectIds();
    hidden.add(projectId);
    await _writeHiddenProjectIds(ids: hidden);
  }

  Future<void> unhideProject({required String projectId}) async {
    final hidden = await getHiddenProjectIds();
    hidden.remove(projectId);
    await _writeHiddenProjectIds(ids: hidden);
  }

  Future<Object?> _readFileJson() async {
    try {
      final content = await _file.readAsString();
      return jsonDecode(content);
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _writeHiddenProjectIds({required Set<String> ids}) async {
    await _file.parent.create(recursive: true);
    final sorted = ids.toList()..sort();
    await _file.writeAsString(jsonEncode(sorted));
  }
}

String _defaultPath() {
  final homeDir = Platform.environment["HOME"] ?? Platform.environment["USERPROFILE"];
  if (homeDir == null) {
    throw StateError("Unable to determine home directory");
  }

  return "$homeDir/.config/sesori-bridge/$_hiddenProjectsFileName";
}
