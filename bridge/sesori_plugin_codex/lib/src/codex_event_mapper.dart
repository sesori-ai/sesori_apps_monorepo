import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "codex_app_server_client.dart";
import "codex_config_reader.dart";
import "repositories/models/codex_thread_record.dart";

/// Translates `codex app-server` `ServerNotification` frames into
/// bridge-neutral [BridgeSseEvent]s.
///
/// The bridge event pipeline requires the `info`/`status` maps on session and
/// message events to be
/// **sesori-schema JSON** — parseable by `Session.fromJson`,
/// `Message.fromJson` and `SessionStatus.fromJson`. Codex's native
/// `thread`/`item`/`status` objects use a different shape, so this mapper
/// builds the typed `sesori_shared` models and serialises them — the same
/// approach the opencode plugin's mapper uses (`model.toJson()`).
///
/// A single codex notification can fan out to several bridge events (an
/// `item/*` notification yields a message envelope plus its content part),
/// so [map] returns a list. An empty list drops the notification — codex
/// has 50+ notification methods and only a subset has a mobile-facing
/// representation today.
class CodexEventMapper {
  CodexEventMapper({
    required this.pluginId,
    required this.projectCwd,
    this.config = const CodexConfigDefaults.empty(),
  });

  final String pluginId;

  /// The bridge launch CWD — codex's single synthesised project id. Used as
  /// the `projectID` for sessions, and as the `directory` fallback when a
  /// notification does not carry the thread's own cwd.
  final String projectCwd;

  /// Global model/provider fallback from `~/.codex/config.toml`. Live
  /// `item`/`turn` notifications do not carry the model, so streaming
  /// assistant messages are stamped with this until the session is re-fetched
  /// from its rollout (the authoritative per-session source).
  final CodexConfigDefaults config;

  /// Per-thread provider captured from `thread/started.modelProvider`, used to
  /// stamp streaming assistant messages.
  final Map<String, String> _threadProvider = {};

  /// Per-thread model id, fed by the plugin from the authoritative codex source
  /// (`thread/start` / `thread/resume` responses and `turn/start` model
  /// overrides). Live `item`/`turn` notifications do not carry the model, so
  /// without this every streamed assistant message would be stamped with the
  /// global [config] default — making a model switch look like it never took
  /// effect even though codex honoured it. Falls back to [config] when unknown.
  final Map<String, String> _threadModel = {};

  /// Records the model codex resolved for [threadId] so subsequent
  /// live-streamed assistant messages are stamped with the model actually in
  /// use. Passing a null/empty [model] clears the override (falls back to the
  /// global config default).
  void setThreadModel(String threadId, String? model) {
    if (model == null || model.isEmpty) {
      _threadModel.remove(threadId);
    } else {
      _threadModel[threadId] = model;
    }
  }

  /// Records the provider codex resolved for [threadId]. Normally fed by the
  /// `thread/started` notification, but a thread resumed from a prior bridge
  /// run never re-emits that notification, so the plugin feeds the provider
  /// from the `thread/resume` response here. Passing a null/empty [provider]
  /// clears the override (falls back to the global config provider).
  void setThreadProvider(String threadId, String? provider) {
    if (provider == null || provider.isEmpty) {
      _threadProvider.remove(threadId);
    } else {
      _threadProvider[threadId] = provider;
    }
  }

  /// Per-thread normalized project directory, fed by the plugin from the cwd it
  /// learns on `thread/start` / `thread/resume`. Live session events carry a
  /// session's own cwd-derived project id — not the launch cwd — so the mobile
  /// session list, opened on that derived project, does not drop them as a
  /// project mismatch. Falls back to [projectCwd] when unknown (e.g. a session
  /// the current bridge run never started or resumed).
  final Map<String, String> _threadDirectory = {};

  /// Records the normalized project [directory] the plugin resolved for
  /// [threadId]. Passing a null/empty [directory] clears the override (falls
  /// back to [projectCwd]).
  void setThreadDirectory(String threadId, String? directory) {
    if (directory == null || directory.isEmpty) {
      _threadDirectory.remove(threadId);
    } else {
      _threadDirectory[threadId] = directory;
    }
  }

  /// The project id a live session event should carry for [threadId]: the
  /// plugin-fed directory, else the notification's own [cwd], else the launch
  /// cwd — always normalized to match the bridge's derived project id.
  String _projectIdForThread(String threadId, {String? cwd}) =>
      normalizeProjectDirectory(directory: _threadDirectory[threadId] ?? cwd ?? projectCwd);

  /// Maps a repository-normalized `thread/started` record.
  List<BridgeSseEvent> mapThreadStarted(CodexThreadRecord record) {
    setThreadProvider(record.id, record.modelProvider);
    setThreadDirectory(record.id, record.directory);
    return [
      BridgeSseSessionCreated(info: _threadToSession(record).toJson()),
    ];
  }

  /// Maps a non-thread-start notification to zero or more bridge events.
  List<BridgeSseEvent> map(CodexServerNotification notification) {
    final method = notification.method;
    final params = notification.params;

    switch (method) {
      case "thread/name/updated":
        final threadId = params["threadId"] as String?;
        if (threadId == null) return const [];
        return [
          BridgeSseSessionUpdated(
            info: _minimalSession(
              id: threadId,
              title: params["threadName"] as String?,
            ).toJson(),
            titleChanged: true,
          ),
        ];

      case "thread/status/changed":
        final threadId = params["threadId"] as String?;
        if (threadId == null) return const [];
        return [
          BridgeSseSessionStatus(
            sessionID: threadId,
            status: _codexStatusToSessionStatus(params["status"]).toJson(),
          ),
        ];

      case "turn/started":
        final threadId = params["threadId"] as String?;
        if (threadId == null) return const [];
        return [
          BridgeSseSessionStatus(
            sessionID: threadId,
            status: const shared.SessionStatus.busy().toJson(),
          ),
        ];

      case "turn/completed":
        final threadId = params["threadId"] as String?;
        if (threadId == null) return const [];
        return [BridgeSseSessionIdle(sessionID: threadId)];

      case "item/started":
      case "item/completed":
        final item = _asMap(params["item"]);
        final threadId = params["threadId"] as String?;
        if (item == null || threadId == null) return const [];
        return _itemToEvents(
          item: item,
          threadId: threadId,
          completed: method == "item/completed",
        );

      case "item/agentMessage/delta":
        return _deltaEvent(params: params, partSuffix: "text");

      case "item/reasoning/textDelta":
      case "item/reasoning/summaryTextDelta":
        return _deltaEvent(params: params, partSuffix: "reasoning");

      case "error":
        return [BridgeSseSessionError(sessionID: params["threadId"] as String?)];

      case "turn/diff/updated":
        final threadId = params["threadId"] as String?;
        if (threadId == null) return const [];
        return [BridgeSseSessionDiff(sessionID: threadId)];

      case "skills/changed":
      case "mcpServer/startupStatus/updated":
        return const [BridgeSseProjectUpdated()];
    }

    // Everything else is dropped intentionally:
    //   - thread/tokenUsage/updated — no Session field for token usage.
    //   - thread/archived | unarchived — the bridge DB is authoritative for
    //     archive state.
    //   - thread/closed — a lifecycle detail, not a user-facing delete.
    //   - item/commandExecution/outputDelta, command/exec/outputDelta —
    //     streaming command output; the full `aggregatedOutput` arrives on the
    //     `item/completed` tool item, which we DO map (see _itemToEvents).
    //   - item/autoApprovalReview/started — approvals arrive separately via
    //     ApprovalRegistry as permission/question events.
    //   - account/*, fs/changed, configWarning, realtime/* … — no analog.
    return const [];
  }

  /// `item/*/delta` notifications stream text into an already-known part.
  List<BridgeSseEvent> _deltaEvent({
    required Map<String, dynamic> params,
    required String partSuffix,
  }) {
    final threadId = params["threadId"] as String?;
    final itemId = params["itemId"] as String?;
    final delta = params["delta"] as String?;
    if (threadId == null || itemId == null || delta == null) return const [];
    return [
      BridgeSseMessagePartDelta(
        sessionID: threadId,
        messageID: itemId,
        partID: "$itemId-$partSuffix",
        field: "text",
        delta: delta,
      ),
    ];
  }

  /// Translates a codex `item` into a message envelope plus its content part.
  ///
  /// [completed] is true for `item/completed` notifications, used to derive a
  /// status for tool items that don't carry one (e.g. `webSearch`).
  List<BridgeSseEvent> _itemToEvents({
    required Map<String, dynamic> item,
    required String threadId,
    required bool completed,
  }) {
    final itemId = item["id"] as String?;
    if (itemId == null || itemId.isEmpty) return const [];

    switch (item["type"] as String?) {
      case "userMessage":
        return _messageEvents(
          threadId: threadId,
          itemId: itemId,
          message: shared.Message.user(
            id: itemId,
            sessionID: threadId,
            agent: null,
            // Live notifications carry no per-message timestamp; the rollout
            // re-fetch is authoritative and fills this in.
            time: null,
          ),
          partType: PluginMessagePartType.text,
          partSuffix: "text",
          text: _extractContentText(item["content"]),
        );
      case "agentMessage":
        return _messageEvents(
          threadId: threadId,
          itemId: itemId,
          message: _assistantMessage(itemId: itemId, threadId: threadId),
          partType: PluginMessagePartType.text,
          partSuffix: "text",
          text: item["text"] as String? ?? _extractContentText(item["content"]),
        );
      case "reasoning":
        return _messageEvents(
          threadId: threadId,
          itemId: itemId,
          message: _assistantMessage(itemId: itemId, threadId: threadId),
          partType: PluginMessagePartType.reasoning,
          partSuffix: "reasoning",
          text: _extractReasoningText(item),
        );
      case "commandExecution":
        return _toolItemEvents(
          threadId: threadId,
          itemId: itemId,
          tool: "shell",
          title: item["command"] as String?,
          status: _toolStatus(item["status"], completed: completed),
          output: item["aggregatedOutput"] as String?,
        );
      case "fileChange":
        return _toolItemEvents(
          threadId: threadId,
          itemId: itemId,
          tool: "edit",
          title: _fileChangeTitle(item["changes"]),
          status: _toolStatus(item["status"], completed: completed),
          output: _fileChangeOutput(item["changes"]),
        );
      case "mcpToolCall":
        return _toolItemEvents(
          threadId: threadId,
          itemId: itemId,
          tool: item["tool"] as String? ?? "mcp",
          title: _mcpToolTitle(item),
          status: _toolStatus(item["status"], completed: completed),
          output: _mcpResultText(item["result"]),
          error: _asMap(item["error"])?["message"] as String?,
        );
      case "webSearch":
        return _toolItemEvents(
          threadId: threadId,
          itemId: itemId,
          tool: "web_search",
          title: item["query"] as String?,
          // webSearch items carry no status field.
          status: completed ? PluginToolStatus.completed : PluginToolStatus.running,
        );
      default:
        // todoList, dynamicToolCall, hookPrompt, … — codex item kinds with no
        // mobile representation yet. Dropped rather than surfaced as broken or
        // empty messages.
        return const [];
    }
  }

  /// Emits an assistant message envelope plus a single `tool` part for a codex
  /// tool/exec/file-change item, so mobile renders the agent's actions (not
  /// just its prose). Mirrors the opencode plugin's tool-part mapping; the
  /// status vocabulary matches what the mobile `ToolPartWidget` renders
  /// (`running`/`completed`/`error`). [output] is shown only when completed;
  /// [error] (falling back to [output]) only when errored.
  List<BridgeSseEvent> _toolItemEvents({
    required String threadId,
    required String itemId,
    required String tool,
    required PluginToolStatus status,
    String? title,
    String? output,
    String? error,
  }) {
    return [
      BridgeSseMessageUpdated(
        info: _assistantMessage(itemId: itemId, threadId: threadId).toJson(),
      ),
      BridgeSseMessagePartUpdated(
        part: PluginMessagePart(
          id: "$itemId-tool",
          sessionID: threadId,
          messageID: itemId,
          type: PluginMessagePartType.tool,
          text: "",
          tool: tool,
          state: PluginToolState(
            status: status,
            title: title,
            output: output,
            error: error ?? (status == PluginToolStatus.error ? output : null),
          ),
          prompt: null,
          description: null,
          agent: null,
          agentName: null,
          attempt: null,
          retryError: null,
        ),
      ),
    ];
  }

  /// Maps a codex item status (`inProgress|completed|failed|declined`) onto the
  /// mobile tool-state vocabulary ([PluginToolStatus]). Items without a
  /// status field fall back to the notification phase ([completed]).
  PluginToolStatus _toolStatus(Object? raw, {required bool completed}) {
    switch (raw is String ? raw : null) {
      case "inProgress":
        return PluginToolStatus.running;
      case "completed":
        return PluginToolStatus.completed;
      case "failed":
      case "declined":
        return PluginToolStatus.error;
    }
    return completed ? PluginToolStatus.completed : PluginToolStatus.running;
  }

  /// A short title for a `fileChange` item: the touched paths (codex's
  /// `changes` are `{path, kind, diff}` entries).
  String? _fileChangeTitle(Object? changes) {
    if (changes is! List || changes.isEmpty) return null;
    final paths = <String>[
      for (final c in changes)
        if (_asMap(c)?["path"] case final String p) p,
    ];
    if (paths.isEmpty) return "${changes.length} file change(s)";
    final shown = paths.take(3).join(", ");
    return paths.length > 3 ? "$shown +${paths.length - 3} more" : shown;
  }

  /// The concatenated unified diffs of a `fileChange` item, if present.
  String? _fileChangeOutput(Object? changes) {
    if (changes is! List) return null;
    final buffer = StringBuffer();
    for (final c in changes) {
      final diff = _asMap(c)?["diff"];
      if (diff is String && diff.isNotEmpty) buffer.writeln(diff);
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? null : result;
  }

  /// A short title for an `mcpToolCall` item (`server/tool`).
  String? _mcpToolTitle(Map<String, dynamic> item) {
    final server = item["server"] as String?;
    final tool = item["tool"] as String?;
    if (server != null && tool != null) return "$server/$tool";
    return tool ?? server;
  }

  /// Best-effort text rendering of an `mcpToolCall` result
  /// (`{content: [{type:text, text}, …]}`).
  String? _mcpResultText(Object? result) {
    final content = _asMap(result)?["content"];
    if (content is! List) return null;
    final buffer = StringBuffer();
    for (final entry in content) {
      final text = _asMap(entry)?["text"];
      if (text is String) buffer.write(text);
    }
    final out = buffer.toString();
    return out.isEmpty ? null : out;
  }

  /// Builds an assistant message stamped with codex's agent/model/provider.
  ///
  /// Model comes from the per-thread model the plugin recorded via
  /// [setThreadModel] (sourced from codex's `thread/start` / `turn/start`
  /// responses), falling back to the global config model when unknown. Provider
  /// comes from the thread's `thread/started.modelProvider`. The persisted
  /// rollout path is authoritative on re-fetch.
  shared.Message _assistantMessage({
    required String itemId,
    required String threadId,
  }) {
    return shared.Message.assistant(
      id: itemId,
      sessionID: threadId,
      agent: "codex",
      modelID: _threadModel[threadId] ?? config.model,
      providerID: _threadProvider[threadId] ?? config.modelProvider ?? "openai",
      // Live notifications carry no per-message timestamp; the rollout
      // re-fetch is authoritative and fills this in.
      time: null,
    );
  }

  /// Emits the message envelope and its (single) content part. The part id
  /// matches the `$itemId-$partSuffix` convention used by [_deltaEvent] so
  /// streaming deltas land on the same part.
  List<BridgeSseEvent> _messageEvents({
    required String threadId,
    required String itemId,
    required shared.Message message,
    required PluginMessagePartType partType,
    required String partSuffix,
    required String? text,
  }) {
    return [
      BridgeSseMessageUpdated(info: message.toJson()),
      BridgeSseMessagePartUpdated(
        part: PluginMessagePart(
          id: "$itemId-$partSuffix",
          sessionID: threadId,
          messageID: itemId,
          type: partType,
          text: text ?? "",
          tool: null,
          state: null,
          prompt: null,
          description: null,
          agent: null,
          agentName: null,
          attempt: null,
          retryError: null,
        ),
      ),
    ];
  }

  /// Builds a full [shared.Session] from a normalized Codex thread record.
  shared.Session _threadToSession(CodexThreadRecord thread) {
    final projectId = _projectIdForThread(
      thread.id,
      cwd: thread.directory,
    );
    return shared.Session(
      branchName: null,
      id: thread.id,
      pluginId: pluginId,
      projectID: projectId,
      directory: projectId,
      parentID: null,
      title: thread.name,
      time: _threadTime(thread),
      pullRequest: null,
      promptDefaults: null,
    );
  }

  /// Builds a minimal [shared.Session] for notifications that only carry an
  /// id (and maybe a title). The bridge enrichment + the mobile client merge
  /// this against existing session state, so the missing fields are filled
  /// in downstream.
  shared.Session _minimalSession({required String id, required String? title}) {
    final projectId = _projectIdForThread(id);
    return shared.Session(
      branchName: null,
      id: id,
      pluginId: pluginId,
      projectID: projectId,
      directory: projectId,
      parentID: null,
      title: title,
      time: null,
      pullRequest: null,
      promptDefaults: null,
    );
  }

  shared.SessionTime? _threadTime(CodexThreadRecord thread) {
    final created = thread.createdAt;
    final updated = thread.updatedAt;
    if (created == null || updated == null) return null;
    return shared.SessionTime(
      created: created,
      updated: updated,
      archived: null,
    );
  }

  /// Maps a codex thread status object (`{type: idle|active, …}`) onto the
  /// sesori [shared.SessionStatus] union. Anything that is not explicitly
  /// `idle` is treated as busy.
  shared.SessionStatus _codexStatusToSessionStatus(Object? raw) {
    final map = _asMap(raw);
    final type = (map?["type"] ?? _asMap(map?["status"])?["type"]) as String?;
    return type == "idle" ? const shared.SessionStatus.idle() : const shared.SessionStatus.busy();
  }

  /// Concatenates the `text` of every text-bearing entry in a codex `content`
  /// list (`text` / `input_text` / `output_text`).
  String? _extractContentText(Object? content) {
    if (content is! List) return null;
    final buffer = StringBuffer();
    for (final entry in content) {
      final map = _asMap(entry);
      if (map == null) continue;
      final type = map["type"] as String?;
      if (type == "text" || type == "input_text" || type == "output_text") {
        final text = map["text"];
        if (text is String) buffer.write(text);
      }
    }
    final result = buffer.toString();
    return result.isEmpty ? null : result;
  }

  /// Pulls reasoning text out of a codex `reasoning` item's `content` and
  /// `summary` lists. Entries may be plain strings or `{text: …}` maps.
  String? _extractReasoningText(Map<String, dynamic> item) {
    final buffer = StringBuffer();
    for (final key in const ["content", "summary"]) {
      final list = item[key];
      if (list is! List) continue;
      for (final entry in list) {
        if (entry is String) {
          buffer.write(entry);
        } else {
          final text = _asMap(entry)?["text"];
          if (text is String) buffer.write(text);
        }
      }
    }
    final result = buffer.toString();
    return result.isEmpty ? null : result;
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }
}
