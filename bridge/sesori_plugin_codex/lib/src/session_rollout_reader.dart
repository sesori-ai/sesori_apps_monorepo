import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        PluginMessage,
        PluginMessagePart,
        PluginMessagePartType,
        PluginMessageWithParts;

/// One line of `~/.codex/session_index.jsonl`.
///
/// Shape (observed on codex-cli 0.121.0):
/// ```jsonl
/// {"id":"019d...","thread_name":"Plan adding new theme version","updated_at":"2026-03-05T22:15:28.679601Z"}
/// ```
class CodexSessionIndexEntry {
  const CodexSessionIndexEntry({
    required this.id,
    required this.threadName,
    required this.updatedAt,
  });

  final String id;
  final String? threadName;
  final DateTime? updatedAt;

  static CodexSessionIndexEntry? tryParse(String line) {
    if (line.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();
      final id = map["id"];
      if (id is! String || id.isEmpty) return null;
      return CodexSessionIndexEntry(
        id: id,
        threadName: map["thread_name"] as String?,
        updatedAt: _tryParseDate(map["updated_at"]),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Header (`session_meta`) record from a rollout JSONL file.
///
/// Shape (observed on codex-cli 0.121.0): a record with
/// `{"type": "session_meta", "payload": {"id", "timestamp", "cwd", ...}}`.
class CodexSessionMeta {
  const CodexSessionMeta({
    required this.id,
    required this.cwd,
    required this.timestamp,
    required this.modelProvider,
    required this.cliVersion,
  });

  final String id;
  final String? cwd;
  final DateTime? timestamp;
  final String? modelProvider;
  final String? cliVersion;
}

/// Combined view of a codex session ready to map to [PluginSession].
class CodexSessionRecord {
  const CodexSessionRecord({
    required this.id,
    required this.rolloutPath,
    required this.cwd,
    required this.threadName,
    required this.createdAt,
    required this.updatedAt,
    required this.cliVersion,
    required this.modelProvider,
  });

  final String id;
  final String rolloutPath;
  final String? cwd;
  final String? threadName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? cliVersion;
  final String? modelProvider;
}

/// Reads codex's on-disk session history.
///
/// All operations are read-only. Reads tolerate partial / corrupted lines
/// (skips and logs nothing) so a single bad record never blocks the rest
/// of a session listing.
///
/// CODEX_HOME resolution mirrors codex itself:
///   1. `$CODEX_HOME` if set.
///   2. `$HOME/.codex` (or `$USERPROFILE\.codex` on Windows).
class SessionRolloutReader {
  SessionRolloutReader({Map<String, String>? environment})
    : _environment = environment ?? Platform.environment;

  final Map<String, String> _environment;

  String? get codexHome {
    final explicit = _environment["CODEX_HOME"];
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final home = _environment["HOME"] ?? _environment["USERPROFILE"];
    if (home == null || home.isEmpty) return null;
    return p.join(home, ".codex");
  }

  /// Returns the absolute path to `session_index.jsonl`, or null if
  /// `$CODEX_HOME` cannot be resolved.
  String? get indexPath {
    final home = codexHome;
    if (home == null) return null;
    return p.join(home, "session_index.jsonl");
  }

  /// Returns the absolute path to the `sessions/` directory, or null if
  /// `$CODEX_HOME` cannot be resolved.
  String? get sessionsDir {
    final home = codexHome;
    if (home == null) return null;
    return p.join(home, "sessions");
  }

  /// Reads `session_index.jsonl` and returns one entry per line.
  ///
  /// Lines that fail to parse are silently skipped (the index is appended
  /// to live by codex; partial lines at EOF are normal).
  List<CodexSessionIndexEntry> readIndex() {
    final path = indexPath;
    if (path == null) return const [];
    final file = File(path);
    if (!file.existsSync()) return const [];
    final lines = file.readAsLinesSync();
    final out = <CodexSessionIndexEntry>[];
    for (final line in lines) {
      final entry = CodexSessionIndexEntry.tryParse(line);
      if (entry != null) out.add(entry);
    }
    return out;
  }

  /// Walks the `sessions/YYYY/MM/DD/` tree and returns every rollout file.
  ///
  /// Each file is named `rollout-<timestamp>-<uuid>.jsonl`. We surface the
  /// UUID in the result so callers can join with [CodexSessionIndexEntry]
  /// without paying for a header parse per file.
  List<({String sessionId, String path})> listRolloutFiles() {
    final root = sessionsDir;
    if (root == null) return const [];
    final dir = Directory(root);
    if (!dir.existsSync()) return const [];

    final out = <({String sessionId, String path})>[];
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith("rollout-") || !name.endsWith(".jsonl")) continue;
      final id = _sessionIdFromRolloutName(name);
      if (id == null) continue;
      out.add((sessionId: id, path: entity.path));
    }
    return out;
  }

  /// Returns the rollout path for [sessionId], if one exists.
  String? findRolloutPath(String sessionId) {
    for (final entry in listRolloutFiles()) {
      if (entry.sessionId == sessionId) return entry.path;
    }
    return null;
  }

  /// Reads only the header record (`session_meta`) from a rollout file.
  ///
  /// Stops scanning as soon as the meta line is found — avoids the cost of
  /// reading the entire transcript when all you need is the CWD.
  CodexSessionMeta? readMeta(String rolloutPath) {
    final file = File(rolloutPath);
    if (!file.existsSync()) return null;
    // Header is usually line 1, but we scan up to ~32 to tolerate any
    // future prefix records that codex might add.
    final lines = file.readAsLinesSync();
    final scanLimit = lines.length < 32 ? lines.length : 32;
    for (var i = 0; i < scanLimit; i++) {
      final line = lines[i];
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map) continue;
        final map = decoded.cast<String, dynamic>();
        if (map["type"] != "session_meta") continue;
        final payload = (map["payload"] as Map?)?.cast<String, dynamic>() ?? {};
        final id = payload["id"];
        if (id is! String || id.isEmpty) continue;
        return CodexSessionMeta(
          id: id,
          cwd: payload["cwd"] as String?,
          timestamp: _tryParseDate(payload["timestamp"]),
          modelProvider: payload["model_provider"] as String?,
          cliVersion: payload["cli_version"] as String?,
        );
      } catch (_) {
        // Try next line.
        continue;
      }
    }
    return null;
  }

  /// Builds the merged view used by [CodexPlugin.getSessions].
  ///
  /// Joins `session_index.jsonl` with each rollout's header. Sessions that
  /// have a rollout file but no index entry (and vice-versa) are still
  /// emitted — we use whichever fields are available.
  List<CodexSessionRecord> listSessions() {
    final rollouts = {
      for (final r in listRolloutFiles()) r.sessionId: r.path,
    };
    final indexEntries = {
      for (final entry in readIndex()) entry.id: entry,
    };

    final ids = <String>{...rollouts.keys, ...indexEntries.keys};
    final out = <CodexSessionRecord>[];
    for (final id in ids) {
      final rolloutPath = rollouts[id];
      final entry = indexEntries[id];
      final meta = rolloutPath != null ? readMeta(rolloutPath) : null;
      // Without a rollout we can't know CWD — drop, since project
      // synthesis depends on CWD.
      if (rolloutPath == null) continue;
      out.add(
        CodexSessionRecord(
          id: id,
          rolloutPath: rolloutPath,
          cwd: meta?.cwd,
          threadName: entry?.threadName,
          createdAt: meta?.timestamp,
          updatedAt: entry?.updatedAt ?? meta?.timestamp,
          cliVersion: meta?.cliVersion,
          modelProvider: meta?.modelProvider,
        ),
      );
    }
    out.sort((a, b) {
      final at = a.updatedAt;
      final bt = b.updatedAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return out;
  }

  /// Reads `response_item` records out of a rollout and maps each one to a
  /// [PluginMessageWithParts]. Tool calls and reasoning are skipped for
  /// Phase 3; later phases enrich the mapping.
  List<PluginMessageWithParts> readMessages(
    String rolloutPath,
    String sessionId,
  ) {
    final file = File(rolloutPath);
    if (!file.existsSync()) return const [];

    final out = <PluginMessageWithParts>[];
    var messageCounter = 0;
    for (final line in file.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map) continue;
        final map = decoded.cast<String, dynamic>();
        if (map["type"] != "response_item") continue;
        final payload = (map["payload"] as Map?)?.cast<String, dynamic>();
        if (payload == null) continue;
        final role = payload["role"] as String?;
        if (role != "user" && role != "assistant") continue;

        final content = payload["content"];
        if (content is! List) continue;
        final texts = <String>[];
        for (final item in content) {
          if (item is! Map) continue;
          final m = item.cast<String, dynamic>();
          final t = m["type"] as String?;
          if (t == "input_text" || t == "output_text") {
            final text = m["text"];
            if (text is String && text.isNotEmpty) texts.add(text);
          }
        }
        if (texts.isEmpty) continue;

        messageCounter += 1;
        final messageId = "m-$messageCounter";
        final info = role == "user"
            ? PluginMessage.user(
                id: messageId,
                sessionID: sessionId,
                agent: null,
              )
            : PluginMessage.assistant(
                id: messageId,
                sessionID: sessionId,
                agent: null,
                modelID: null,
                providerID: null,
              );
        final parts = <PluginMessagePart>[
          for (var i = 0; i < texts.length; i++)
            PluginMessagePart(
              id: "$messageId-p$i",
              sessionID: sessionId,
              messageID: messageId,
              type: PluginMessagePartType.text,
              text: texts[i],
              tool: null,
              state: null,
              prompt: null,
              description: null,
              agent: null,
              agentName: null,
              attempt: null,
              retryError: null,
            ),
        ];
        out.add(PluginMessageWithParts(info: info, parts: parts));
      } catch (_) {
        // Bad line — skip and continue.
        continue;
      }
    }
    return out;
  }

  /// Deletes the rollout file for [sessionId] and drops its entry from
  /// `session_index.jsonl`. Best-effort: missing files are silently
  /// ignored so callers can use this as an idempotent "ensure removed".
  void deleteSession(String sessionId) {
    final rolloutPath = findRolloutPath(sessionId);
    if (rolloutPath != null) {
      try {
        File(rolloutPath).deleteSync();
      } catch (_) {
        // Best-effort.
      }
    }
    _removeIndexEntry(sessionId);
  }

  void _removeIndexEntry(String sessionId) {
    final path = indexPath;
    if (path == null) return;
    final file = File(path);
    if (!file.existsSync()) return;
    final lines = file.readAsLinesSync();
    final filtered = <String>[];
    for (final line in lines) {
      final entry = CodexSessionIndexEntry.tryParse(line);
      if (entry?.id == sessionId) continue;
      filtered.add(line);
    }
    if (filtered.length == lines.length) return;
    file.writeAsStringSync(filtered.isEmpty ? "" : "${filtered.join("\n")}\n");
  }

  static String? _sessionIdFromRolloutName(String fileName) {
    // rollout-2026-04-17T14-31-04-019d9ba3-4e94-7530-9e3e-7f812a426859.jsonl
    // The UUID is the trailing 5 hyphen-separated groups before `.jsonl`.
    if (!fileName.endsWith(".jsonl")) return null;
    final stem = fileName.substring(0, fileName.length - ".jsonl".length);
    final parts = stem.split("-");
    if (parts.length < 5) return null;
    final uuidParts = parts.sublist(parts.length - 5);
    final uuid = uuidParts.join("-");
    // Cheap UUID-shape check (32 hex chars + 4 hyphens).
    if (uuid.length != 36) return null;
    return uuid;
  }
}

DateTime? _tryParseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
