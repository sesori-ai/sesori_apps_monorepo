import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show resolveUserHomeDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "models/grok_session_notification_dto.dart";
import "models/grok_session_store_dto.dart";

/// Reads Grok Build's persisted sessions tree,
/// `<home>/.grok/sessions/<percent-encoded cwd>/<session id>/`. Dumb file
/// access and DTO parsing only; the catalog repository decides what the
/// records mean. A missing tree, directory, or file reads as empty.
class GrokSessionStoreApi({
  /// The `sessions` directory, or null when no home directory is known.
  required final String? sessionsRoot,
  required final String pluginId,
}) {
  static const String summaryFileName = "summary.json";
  static const String updatesFileName = "updates.jsonl";

  /// The store under the user's home directory, resolved through the bridge
  /// foundation (never `HOME` directly).
  factory forHome({
    required Map<String, String> environment,
    required String pluginId,
  }) {
    final home = resolveUserHomeDirectory(environment: environment);
    return GrokSessionStoreApi(
      sessionsRoot: home == null ? null : p.join(home, ".grok", "sessions"),
      pluginId: pluginId,
    );
  }

  /// Grok keys a project by its percent-encoded cwd (`/` becomes `%2F`).
  static String encodeCwd({required String cwd}) => Uri.encodeComponent(cwd);

  String? _projectDirectory({required String cwd}) {
    final root = sessionsRoot;
    return root == null ? null : p.join(root, encodeCwd(cwd: cwd));
  }

  /// Every cwd with a persisted project directory, in no particular order.
  List<String> listProjectDirectories() {
    final root = sessionsRoot;
    if (root == null) return const [];
    final directory = Directory(root);
    return [
      for (final entry in _listIfPresent(directory: directory))
        if (entry is Directory) Uri.decodeComponent(p.basename(entry.path)),
    ];
  }

  /// Every session id persisted for [cwd], in no particular order.
  List<String> listSessionIds({required String cwd}) {
    final project = _projectDirectory(cwd: cwd);
    if (project == null) return const [];
    final directory = Directory(project);
    return [
      for (final entry in _listIfPresent(directory: directory))
        if (entry is Directory) p.basename(entry.path),
    ];
  }

  List<FileSystemEntity> _listIfPresent({required Directory directory}) {
    if (!directory.existsSync()) return const [];
    try {
      return directory.listSync(followLinks: false);
    } on FileSystemException {
      // A directory removed between the check and listing is still ordinary
      // absence. Permission and other I/O failures remain observable.
      if (!directory.existsSync()) return const [];
      rethrow;
    }
  }

  String _sessionDirectory({required String project, required String sessionId}) {
    if (sessionId.isEmpty ||
        sessionId == "." ||
        sessionId == ".." ||
        sessionId.contains("/") ||
        sessionId.contains(r"\")) {
      throw ArgumentError.value(sessionId, "sessionId", "must be one safe path component");
    }
    return p.join(project, sessionId);
  }

  GrokSessionSummaryDto? readSummary({required String cwd, required String sessionId}) {
    final project = _projectDirectory(cwd: cwd);
    if (project == null) return null;
    final file = File(p.join(_sessionDirectory(project: project, sessionId: sessionId), summaryFileName));
    if (!file.existsSync()) return null;
    return GrokSessionSummaryDto.fromJson(jsonDecodeMap(file.readAsStringSync()));
  }

  /// The `subagent_spawned` records [sessionId] persisted, in file order.
  /// Unparseable lines and other update kinds are skipped.
  List<GrokSubagentSpawned> readSpawnRecords({required String cwd, required String sessionId}) {
    final project = _projectDirectory(cwd: cwd);
    if (project == null) return const [];
    final file = File(p.join(_sessionDirectory(project: project, sessionId: sessionId), updatesFileName));
    if (!file.existsSync()) return const [];
    final spawns = <GrokSubagentSpawned>[];
    for (final line in file.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final envelope = GrokPersistedUpdateDto.fromJson(jsonDecodeMap(line));
        if (envelope case GrokPersistedSessionUpdateDto(:final params)) {
          if (params.update case final GrokSubagentSpawned spawned) spawns.add(spawned);
        }
      } on Object catch (error, stackTrace) {
        // The file carries many unrelated update variants. Typed unknown
        // variants are skipped above; malformed envelopes remain observable.
        Log.w("[$pluginId] skipping unreadable session update at ${file.path}", error, stackTrace);
      }
    }
    return spawns;
  }
}
