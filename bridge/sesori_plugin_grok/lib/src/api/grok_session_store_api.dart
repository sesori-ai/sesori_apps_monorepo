import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show resolveUserHomeDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "models/grok_session_notification_dto.dart";
import "models/grok_session_store_dto.dart";

/// Reads Grok Build's persisted sessions tree,
/// `<home>/.grok/sessions/<percent-encoded cwd>/<session id>/`. Dumb file
/// access and DTO parsing only; the catalog repository decides what the
/// records mean. A missing tree, directory, or file reads as empty.
class GrokSessionStoreApi({
  /// The `sessions` directory, or null when no home directory is known.
  required final String? sessionsRoot,
}) {
  static const String summaryFileName = "summary.json";
  static const String updatesFileName = "updates.jsonl";

  /// The store under the user's home directory, resolved through the bridge
  /// foundation (never `HOME` directly).
  factory forHome({required Map<String, String> environment}) {
    final home = resolveUserHomeDirectory(environment: environment);
    return GrokSessionStoreApi(sessionsRoot: home == null ? null : p.join(home, ".grok", "sessions"));
  }

  /// Grok keys a project by its percent-encoded cwd (`/` becomes `%2F`).
  static String encodeCwd({required String cwd}) => Uri.encodeComponent(cwd);

  String? _projectDirectory({required String cwd}) {
    final root = sessionsRoot;
    return root == null ? null : p.join(root, encodeCwd(cwd: cwd));
  }

  /// Every session id persisted for [cwd], in no particular order.
  List<String> listSessionIds({required String cwd}) {
    final project = _projectDirectory(cwd: cwd);
    if (project == null) return const [];
    final directory = Directory(project);
    if (!directory.existsSync()) return const [];
    return [
      for (final entry in directory.listSync(followLinks: false))
        if (entry is Directory) p.basename(entry.path),
    ];
  }

  GrokSessionSummaryDto? readSummary({required String cwd, required String sessionId}) {
    final project = _projectDirectory(cwd: cwd);
    if (project == null) return null;
    final file = File(p.join(project, sessionId, summaryFileName));
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return null;
      // ignore: no_slop_linter/prefer_specific_type, JSON object values are heterogeneous
      return GrokSessionSummaryDto.fromJson(decoded.cast<String, dynamic>());
    } on Object catch (error, stackTrace) {
      Log.w("[grok] unreadable session summary at ${file.path}", error, stackTrace);
      return null;
    }
  }

  /// The `subagent_spawned` records [sessionId] persisted, in file order.
  /// Unparseable lines and other update kinds are skipped.
  List<GrokSubagentSpawned> readSpawnRecords({required String cwd, required String sessionId}) {
    final project = _projectDirectory(cwd: cwd);
    if (project == null) return const [];
    final file = File(p.join(project, sessionId, updatesFileName));
    if (!file.existsSync()) return const [];
    final List<String> lines;
    try {
      lines = file.readAsLinesSync();
    } on Object catch (error, stackTrace) {
      Log.w("[grok] unreadable session updates at ${file.path}", error, stackTrace);
      return const [];
    }
    final spawns = <GrokSubagentSpawned>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map) continue;
        // ignore: no_slop_linter/prefer_specific_type, JSON object values are heterogeneous
        final params = GrokPersistedUpdateDto.fromJson(decoded.cast<String, dynamic>()).params;
        if (params == null) continue;
        final notification = GrokSessionNotificationDto.fromJson(params);
        if (notification.update case final GrokSubagentSpawned spawned) spawns.add(spawned);
      } on Object {
        // A malformed or foreign line carries nothing this reader needs; the
        // file has thousands of other update kinds that parse as unknown.
        continue;
      }
    }
    return spawns;
  }
}
