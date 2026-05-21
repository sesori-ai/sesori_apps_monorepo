import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "codex_app_server_client.dart";

/// Translates `codex app-server` `ServerNotification` frames into
/// bridge-neutral [BridgeSseEvent]s.
///
/// The bridge core ([BridgeEventMapper] / [SessionEventEnrichmentService])
/// requires the `info`/`status` maps on session and message events to be
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
  const CodexEventMapper({required this.projectCwd});

  /// The bridge launch CWD — codex's single synthesised project id. Used as
  /// the `projectID` for sessions, and as the `directory` fallback when a
  /// notification does not carry the thread's own cwd.
  final String projectCwd;

  /// Maps a single notification to zero or more bridge events.
  List<BridgeSseEvent> map(CodexServerNotification notification) {
    final method = notification.method;
    final params = notification.params;

    switch (method) {
      case "thread/started":
        final thread = _asMap(params["thread"]);
        final id = thread?["id"] as String?;
        if (thread == null || id == null || id.isEmpty) return const [];
        return [
          BridgeSseSessionCreated(info: _threadToSession(thread, id).toJson()),
        ];

      case "thread/name/updated":
        final threadId = params["threadId"] as String?;
        if (threadId == null) return const [];
        return [
          BridgeSseSessionUpdated(
            info: _minimalSession(
              id: threadId,
              title: params["threadName"] as String?,
            ).toJson(),
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
        return _itemToEvents(item: item, threadId: threadId);

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
    //   - item/commandExecution/outputDelta, command/exec/outputDelta,
    //     item/autoApprovalReview/started — tool/approval surfaces the
    //     mobile UI has no renderer for here (approvals arrive separately
    //     via ApprovalRegistry as permission/question events).
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
  List<BridgeSseEvent> _itemToEvents({
    required Map<String, dynamic> item,
    required String threadId,
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
          ),
          partType: PluginMessagePartType.text,
          partSuffix: "text",
          text: _extractContentText(item["content"]),
        );
      case "agentMessage":
        return _messageEvents(
          threadId: threadId,
          itemId: itemId,
          message: shared.Message.assistant(
            id: itemId,
            sessionID: threadId,
            agent: null,
            modelID: null,
            providerID: null,
          ),
          partType: PluginMessagePartType.text,
          partSuffix: "text",
          text: item["text"] as String? ?? _extractContentText(item["content"]),
        );
      case "reasoning":
        return _messageEvents(
          threadId: threadId,
          itemId: itemId,
          message: shared.Message.assistant(
            id: itemId,
            sessionID: threadId,
            agent: null,
            modelID: null,
            providerID: null,
          ),
          partType: PluginMessagePartType.reasoning,
          partSuffix: "reasoning",
          text: _extractReasoningText(item),
        );
      default:
        // commandExecution, fileChange, todoList, webSearch, … — codex item
        // kinds the mobile UI has no renderer for yet. Dropped rather than
        // surfaced as broken or empty messages.
        return const [];
    }
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

  /// Builds a full [shared.Session] from a codex `thread` object.
  shared.Session _threadToSession(Map<String, dynamic> thread, String id) {
    return shared.Session(
      id: id,
      projectID: projectCwd,
      directory: thread["cwd"] as String? ?? projectCwd,
      parentID: null,
      title: thread["name"] as String?,
      time: _threadTime(thread),
      summary: null,
      pullRequest: null,
      promptDefaults: null,
    );
  }

  /// Builds a minimal [shared.Session] for notifications that only carry an
  /// id (and maybe a title). The bridge enrichment + the mobile client merge
  /// this against existing session state, so the missing fields are filled
  /// in downstream.
  shared.Session _minimalSession({required String id, required String? title}) {
    return shared.Session(
      id: id,
      projectID: projectCwd,
      directory: projectCwd,
      parentID: null,
      title: title,
      time: null,
      summary: null,
      pullRequest: null,
      promptDefaults: null,
    );
  }

  /// Codex timestamps are unix **seconds**; sesori [shared.SessionTime] is in
  /// **milliseconds**.
  shared.SessionTime? _threadTime(Map<String, dynamic> thread) {
    final created = thread["createdAt"];
    final updated = thread["updatedAt"];
    if (created is! num || updated is! num) return null;
    return shared.SessionTime(
      created: (created * 1000).round(),
      updated: (updated * 1000).round(),
      archived: null,
    );
  }

  /// Maps a codex thread status object (`{type: idle|active, …}`) onto the
  /// sesori [shared.SessionStatus] union. Anything that is not explicitly
  /// `idle` is treated as busy.
  shared.SessionStatus _codexStatusToSessionStatus(Object? raw) {
    final map = _asMap(raw);
    final type = (map?["type"] ?? _asMap(map?["status"])?["type"]) as String?;
    return type == "idle"
        ? const shared.SessionStatus.idle()
        : const shared.SessionStatus.busy();
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
