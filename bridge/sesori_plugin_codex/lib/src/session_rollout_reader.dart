import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        PluginMessage,
        PluginMessagePart,
        PluginMessagePartType,
        PluginMessageTime,
        PluginMessageWithParts,
        PluginToolState,
        PluginToolStatus;

import "codex_config_reader.dart";

/// One line of `~/.codex/session_index.jsonl`.
///
/// Shape (observed on codex-cli 0.139.0):
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
/// Shape (observed on codex-cli 0.139.0): a record with
/// `{"type": "session_meta", "payload": {"id", "timestamp", "cwd", ...}}`.
class CodexSessionMeta {
  const CodexSessionMeta({
    required this.id,
    required this.cwd,
    required this.timestamp,
    required this.modelProvider,
    required this.model,
    required this.cliVersion,
  });

  final String id;
  final String? cwd;
  final DateTime? timestamp;
  final String? modelProvider;

  /// The session's model id, read from the latest `turn_context` record seen
  /// in the header scan window. `session_meta` itself does not carry the
  /// model — only the provider.
  final String? model;
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
    required this.model,
  });

  final String id;
  final String rolloutPath;
  final String? cwd;
  final String? threadName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? cliVersion;
  final String? modelProvider;
  final String? model;
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
    // The `session_meta` header is line 1, but the model lives in a
    // `turn_context` record that follows it. Scan a bounded window so we can
    // capture both without reading the whole transcript when all we need is
    // the session header.
    final lines = file.readAsLinesSync();
    final scanLimit = lines.length < 32 ? lines.length : 32;

    String? id;
    String? cwd;
    DateTime? timestamp;
    String? modelProvider;
    String? cliVersion;
    String? model;

    for (var i = 0; i < scanLimit; i++) {
      try {
        final decoded = jsonDecode(lines[i]);
        if (decoded is! Map) continue;
        final map = decoded.cast<String, dynamic>();
        final type = map["type"];
        if (type == "session_meta") {
          final payload =
              (map["payload"] as Map?)?.cast<String, dynamic>() ?? {};
          final metaId = payload["id"];
          if (metaId is! String || metaId.isEmpty) continue;
          id = metaId;
          cwd = payload["cwd"] as String?;
          timestamp = _tryParseDate(payload["timestamp"]);
          modelProvider = payload["model_provider"] as String?;
          cliVersion = payload["cli_version"] as String?;
        } else if (type == "turn_context") {
          final payload = (map["payload"] as Map?)?.cast<String, dynamic>();
          final m = payload?["model"];
          // Latest within the window wins — the model can change mid-session.
          if (m is String && m.isNotEmpty) model = m;
        }
      } catch (_) {
        // Skip bad lines.
        continue;
      }
    }

    if (id == null) return null;
    return CodexSessionMeta(
      id: id,
      cwd: cwd,
      timestamp: timestamp,
      modelProvider: modelProvider,
      model: model,
      cliVersion: cliVersion,
    );
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
          model: meta?.model,
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
  /// [PluginMessageWithParts].
  ///
  /// Assistant messages are stamped with the session's model metadata so the
  /// mobile UI can render the model in the session subtitle: the provider
  /// comes from the `session_meta` header, the model id from the most recent
  /// `turn_context` seen *before* the message (the model can change
  /// mid-session). [config] supplies the global fallback for either field when
  /// the rollout itself doesn't carry it.
  List<PluginMessageWithParts> readMessages(
    String rolloutPath,
    String sessionId, {
    CodexConfigDefaults config = const CodexConfigDefaults.empty(),
  }) {
    final file = File(rolloutPath);
    if (!file.existsSync()) return const [];

    final lines = file.readAsLinesSync();

    // Pre-scan: a tool call (`function_call`) and its result
    // (`function_call_output`) are separate records correlated by `call_id`.
    // Collect the outputs up front so the forward pass can render each call
    // with its result (and a completed status) in one tool part.
    final toolOutputs = <String, String>{};
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final payload = (jsonDecode(line) as Map?)?["payload"];
        if (payload is! Map) continue;
        if (payload["type"] != "function_call_output") continue;
        final callId = payload["call_id"] as String?;
        final output = payload["output"];
        if (callId != null && output is String) toolOutputs[callId] = output;
      } catch (_) {
        continue;
      }
    }

    final out = <PluginMessageWithParts>[];
    var messageCounter = 0;
    String? sessionProvider;
    String? currentModel;

    PluginMessage assistantInfo(String id, PluginMessageTime? time) =>
        PluginMessage.assistant(
          id: id,
          sessionID: sessionId,
          agent: "codex",
          modelID: currentModel ?? config.model,
          providerID: sessionProvider ?? config.modelProvider ?? "openai",
          time: time,
        );

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map) continue;
        final map = decoded.cast<String, dynamic>();
        final type = map["type"];
        if (type == "session_meta") {
          final payload = (map["payload"] as Map?)?.cast<String, dynamic>();
          sessionProvider ??= payload?["model_provider"] as String?;
          continue;
        }
        if (type == "turn_context") {
          final payload = (map["payload"] as Map?)?.cast<String, dynamic>();
          final m = payload?["model"];
          if (m is String && m.isNotEmpty) currentModel = m;
          continue;
        }
        if (type != "response_item") continue;
        final payload = (map["payload"] as Map?)?.cast<String, dynamic>();
        if (payload == null) continue;
        // Codex stamps each rollout record with a top-level ISO `timestamp`;
        // surface it so the mobile UI can render the per-message time. Absent
        // or unparseable timestamps degrade to null (no time shown).
        final messageTime = _messageTimeFrom(map["timestamp"]);
        final payloadType = payload["type"] as String?;

        // Tool / command / file-edit activity — the substance of a coding
        // session. Surface each as an assistant message with one tool part so
        // re-fetched history matches what the live event mapper streams.
        if (payloadType == "function_call") {
          final callId = payload["call_id"] as String?;
          final name = payload["name"] as String? ?? "tool";
          final args = payload["arguments"] as String?;
          final output = callId == null ? null : toolOutputs[callId];
          messageCounter += 1;
          out.add(
            _toolMessage(
              messageId: "m-$messageCounter",
              sessionId: sessionId,
              info: assistantInfo("m-$messageCounter", messageTime),
              tool: _normalizeToolName(name),
              title: _toolCallTitle(args),
              status: output != null ? PluginToolStatus.completed : PluginToolStatus.running,
              output: output,
            ),
          );
          continue;
        }
        if (payloadType == "function_call_output") {
          continue; // already folded into its function_call above
        }
        if (payloadType == "web_search_call") {
          final action = (payload["action"] as Map?)?.cast<String, dynamic>();
          messageCounter += 1;
          out.add(
            _toolMessage(
              messageId: "m-$messageCounter",
              sessionId: sessionId,
              info: assistantInfo("m-$messageCounter", messageTime),
              tool: "web_search",
              title: action?["query"] as String?,
              status: PluginToolStatus.completed,
              output: null,
            ),
          );
          continue;
        }

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
                time: messageTime,
              )
            : assistantInfo(messageId, messageTime);
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

  /// Maximum tool-output length surfaced in history; longer outputs are
  /// truncated to keep message payloads bounded (mirrors the opencode plugin).
  static const int _maxToolOutputLength = 8000;

  /// Builds a one-tool-part assistant message for a rollout tool record.
  PluginMessageWithParts _toolMessage({
    required String messageId,
    required String sessionId,
    required PluginMessage info,
    required String tool,
    required PluginToolStatus status,
    String? title,
    String? output,
  }) {
    final clipped = output != null && output.length > _maxToolOutputLength
        ? output.substring(0, _maxToolOutputLength)
        : output;
    return PluginMessageWithParts(
      info: info,
      parts: [
        PluginMessagePart(
          id: "$messageId-tool",
          sessionID: sessionId,
          messageID: messageId,
          type: PluginMessagePartType.tool,
          text: "",
          tool: tool,
          state: PluginToolState(
            status: status,
            title: title,
            output: clipped,
            error: null,
          ),
          prompt: null,
          description: null,
          agent: null,
          agentName: null,
          attempt: null,
          retryError: null,
        ),
      ],
    );
  }

  /// Normalises a codex function-call name to the tool label the live mapper
  /// uses, so live and re-fetched history render consistently.
  static String _normalizeToolName(String name) {
    final n = name.toLowerCase();
    if (n.contains("patch") || n.contains("edit") || n.contains("write")) {
      return "edit";
    }
    if (n.contains("exec") ||
        n.contains("shell") ||
        n.contains("bash") ||
        n.contains("command")) {
      return "shell";
    }
    return name;
  }

  /// A short title for a function call, pulled from its JSON `arguments`
  /// (`cmd`/`command`/`path`/`query`), falling back to the raw (clipped) args.
  static String? _toolCallTitle(String? argumentsJson) {
    if (argumentsJson == null || argumentsJson.isEmpty) return null;
    try {
      final args = jsonDecode(argumentsJson);
      if (args is Map) {
        for (final key in const ["cmd", "command", "path", "file_path", "query"]) {
          final value = args[key];
          if (value is String && value.isNotEmpty) return value;
          if (value is List && value.isNotEmpty) return value.join(" ");
        }
      }
    } catch (_) {
      // Fall through to the raw arguments.
    }
    return argumentsJson.length > 120
        ? argumentsJson.substring(0, 120)
        : argumentsJson;
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

/// Builds a [PluginMessageTime] from a codex rollout record's top-level
/// `timestamp`. The record carries only a single instant, so it maps to
/// `created`; `completed` stays null. Unparseable/absent timestamps yield null.
PluginMessageTime? _messageTimeFrom(Object? raw) {
  final parsed = _tryParseDate(raw);
  if (parsed == null) return null;
  return PluginMessageTime(
    created: parsed.millisecondsSinceEpoch,
    completed: null,
  );
}
