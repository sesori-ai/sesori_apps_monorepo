import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "acp_content.dart";
import "acp_protocol.dart";
import "acp_stdio_client.dart";

/// Translates ACP `session/update` notifications into bridge-neutral
/// [BridgeSseEvent]s.
///
/// Like the codex mapper, the `info` maps on session/message events MUST be
/// sesori-schema JSON (parseable by `Message.fromJson` / `Session.fromJson`),
/// so we build typed `sesori_shared` models and `.toJson()` them.
///
/// ACP differs from codex's app-server protocol in two ways that shape this
/// mapper:
///  1. There are no `turn/started` / `turn/completed` notifications — the
///     plugin derives busy/idle from the `session/prompt` future, so this
///     mapper does not emit session-status events.
///  2. Streaming chunks (`agent_message_chunk`, …) carry no message id, so we
///     synthesize a stable per-turn id. The plugin calls [beginTurn] before
///     each `session/prompt` to advance the turn counter.
///
/// Harness-specific notifications (e.g. Cursor's `cursor/*`) are routed to
/// [mapExtension], which subclasses override.
class AcpEventMapper {
  AcpEventMapper({required String launchDirectory, required this.agentId})
    : launchDirectory = normalizeProjectDirectory(directory: launchDirectory);

  /// The bridge launch directory (canonicalized) — the fallback project
  /// attribution for sessions whose own directory is not (yet) known. Matches
  /// the canonical project id the bridge derives for the same directory.
  final String launchDirectory;

  /// Agent name stamped on assistant messages (e.g. "cursor").
  final String agentId;

  /// Global fallback model/provider stamped on assistant messages when a
  /// session has no specific model recorded. The plugin sets these once the
  /// model catalog resolves.
  String? currentModelId;
  String? currentProviderId;

  /// Per-session model/provider. ACP's live `*_chunk` notifications carry no
  /// model, so the plugin records the resolved per-session model here (via
  /// [setSessionModel]); without it every streamed message would be stamped
  /// with the global [currentModelId], making a per-session model switch look
  /// like it never took effect.
  final Map<String, String> _sessionModel = {};
  final Map<String, String> _sessionProvider = {};

  /// Records the model/provider resolved for [sessionId]. A null/empty
  /// [modelId] clears the override (falls back to [currentModelId]).
  void setSessionModel(String sessionId, String? modelId, {String? providerId}) {
    if (modelId == null || modelId.isEmpty) {
      _sessionModel.remove(sessionId);
    } else {
      _sessionModel[sessionId] = modelId;
    }
    if (providerId != null && providerId.isNotEmpty) {
      _sessionProvider[sessionId] = providerId;
    }
  }

  /// The model/provider to stamp on [sessionId]'s assistant messages.
  String? modelForSession(String sessionId) =>
      _sessionModel[sessionId] ?? currentModelId;
  String? providerForSession(String sessionId) =>
      _sessionProvider[sessionId] ?? currentProviderId;

  /// Last-known per-session metadata (title/times), fed by the plugin from
  /// enumeration and creation (like [setSessionProject]). `session_info_update`
  /// merges against it so the emitted `session.updated` payload doesn't null
  /// out the session's time — which would make the mobile list row lose its
  /// sort position until a full refresh.
  final Map<String, _SessionSnapshot> _sessionSnapshots = {};

  /// Records the last-known [title]/[createdMs]/[updatedMs] for [sessionId].
  /// A null field leaves the prior value in place (an enumeration hit may
  /// know times but not a cleared title). Title and updated take the latest
  /// value; created keeps the earliest known (enumeration only reports
  /// last-activity time, which must not drag the creation time forward).
  void setSessionSnapshot({
    required String sessionId,
    required String? title,
    required int? createdMs,
    required int? updatedMs,
  }) {
    final snapshot = _sessionSnapshots.putIfAbsent(sessionId, _SessionSnapshot.new);
    if (title != null && title.isNotEmpty) snapshot.title = title;
    if (createdMs != null) {
      final prior = snapshot.createdMs;
      snapshot.createdMs = prior == null || createdMs < prior ? createdMs : prior;
    }
    if (updatedMs != null) snapshot.updatedMs = updatedMs;
  }

  /// Commands last advertised by the agent via `available_commands_update`,
  /// served by the plugin's `getCommands`. Process-global (last update wins):
  /// ACP scopes the notification per session, but the commands are agent-global
  /// for every shipping backend, and `getCommands` is project-scoped — so a
  /// per-session cache would invent scoping the API can't express.
  List<PluginCommand> get availableCommands => List.unmodifiable(_availableCommands);
  List<PluginCommand> _availableCommands = const [];

  /// Per-session project directory (an ACP project id *is* its `cwd`). The
  /// plugin records it so `session_info_update` (title) events are filed under
  /// the session's real project, not the launch [launchDirectory]. The mobile
  /// session list drops `session.updated` events whose projectID does not match
  /// the active project, so a session opened outside the launch directory would
  /// otherwise have its title updates ignored (or misrouted to the launch
  /// project).
  final Map<String, String> _sessionProject = {};

  /// Records the project directory [sessionId] belongs to. A null/empty
  /// [directory] clears the override (falls back to [launchDirectory]).
  void setSessionProject(String sessionId, String? directory) {
    if (directory == null || directory.isEmpty) {
      _sessionProject.remove(sessionId);
    } else {
      _sessionProject[sessionId] = directory;
    }
  }

  /// The project id/directory to stamp on [sessionId]'s session-level events.
  String projectForSession(String sessionId) =>
      _sessionProject[sessionId] ?? launchDirectory;

  /// Drops every per-session cache entry for [sessionId] — called when the
  /// session is deleted so live-render state (model, project, turn counters,
  /// started parts, live tools) doesn't accumulate across a long-lived process.
  void forgetSession(String sessionId) {
    _sessionModel.remove(sessionId);
    _sessionProvider.remove(sessionId);
    _sessionProject.remove(sessionId);
    _sessionSnapshots.remove(sessionId);
    _turnSeq.remove(sessionId);
    _startedParts.remove(sessionId);
    // Exact per-session removal — session ids are opaque agent strings that may
    // themselves contain ':', so a prefix match on a composite key could wipe a
    // different session's tools.
    _liveTools.remove(sessionId);
  }

  /// sessionId -> (toolCallId -> last-rendered live tool state). ACP
  /// `tool_call_update` notifications are partial, so this preserves the tool's
  /// name/title/status/output across updates that omit them. Nested (not a
  /// composite "sessionId:toolCallId" key) so cleanup is exact regardless of
  /// characters in the opaque agent-supplied ids.
  final Map<String, Map<String, _LiveTool>> _liveTools = {};

  /// sessionId -> current turn number, advanced by [beginTurn].
  final Map<String, int> _turnSeq = {};

  /// Per-session part ids whose envelope/part has already been emitted in the
  /// current turn. Scoped per session and pruned on [beginTurn] so it cannot
  /// grow without bound across a long-running session.
  final Map<String, Set<String>> _startedParts = {};

  /// Advance the turn counter for [sessionId]. Call before `session/prompt`
  /// so the next batch of streamed chunks groups under a fresh message id.
  void beginTurn(String sessionId) {
    _turnSeq[sessionId] = (_turnSeq[sessionId] ?? 0) + 1;
    // The new turn uses fresh (turn-numbered) part ids, so the prior turn's are
    // dead weight — drop them to bound memory in long sessions.
    _startedParts.remove(sessionId);
    // Tool state is retained across a turn (so a reordered late `tool_call_update`
    // still merges onto its terminal state instead of blanking the card), and
    // cleared here at the turn boundary to keep it bounded.
    _liveTools.remove(sessionId);
  }

  int _turn(String sessionId) => _turnSeq[sessionId] ?? 1;

  /// Maps a single notification to zero or more bridge events.
  List<BridgeSseEvent> map(AcpNotification notification) {
    if (notification.method != AcpMethods.sessionUpdate) {
      return mapExtension(notification);
    }
    final params = notification.params;
    final sessionId = params["sessionId"] as String?;
    final update = _asMap(params["update"]);
    if (sessionId == null || sessionId.isEmpty || update == null) {
      return const [];
    }

    switch (update["sessionUpdate"] as String?) {
      case "agent_message_chunk":
        return _textChunk(
          sessionId: sessionId,
          update: update,
          role: _ChunkRole.assistant,
          partSuffix: "text",
          partType: PluginMessagePartType.text,
        );
      case "agent_thought_chunk":
        return _textChunk(
          sessionId: sessionId,
          update: update,
          role: _ChunkRole.assistant,
          partSuffix: "reasoning",
          partType: PluginMessagePartType.reasoning,
        );
      case "user_message_chunk":
        return _textChunk(
          sessionId: sessionId,
          update: update,
          role: _ChunkRole.user,
          partSuffix: "text",
          partType: PluginMessagePartType.text,
        );
      case "tool_call":
        return _toolCall(sessionId: sessionId, update: update);
      case "tool_call_update":
        return _toolCallUpdate(sessionId: sessionId, update: update);
      case "plan":
        return [BridgeSseTodoUpdated(sessionID: sessionId)];
      case "available_commands_update":
        // Cache the advertised commands so `getCommands` can serve them; the
        // refresh event tells the phone to re-fetch.
        _availableCommands = _parseAvailableCommands(update["availableCommands"]);
        return const [BridgeSseProjectUpdated()];
      case "session_info_update":
        // The notification may carry `updatedAt` (ISO 8601 or epoch) — keep
        // the snapshot's recency fresh even when no title change is emitted.
        final eventUpdatedMs = _timestampMs(update["updatedAt"]);
        if (eventUpdatedMs != null) {
          setSessionSnapshot(
            sessionId: sessionId,
            title: null,
            createdMs: null,
            updatedMs: eventUpdatedMs,
          );
        }
        // The agent's auto-generated title for the thread. Surfaced as a
        // session update so the mobile session list / app bar live-update.
        // Only emit when the update actually carries a `title` field: absent =
        // some other metadata changed (no title change), while an explicit null
        // or empty clears the title (ACP v1 documents `title` as nullable, null
        // clears) — forward that clear rather than dropping it, else the phone
        // keeps the stale title until a full refresh.
        if (!update.containsKey("title")) return const [];
        final rawTitle = update["title"];
        final title = rawTitle is String && rawTitle.isNotEmpty ? rawTitle : null;
        // Keep the snapshot's title in sync (including a clear) so a later
        // emission doesn't resurrect the old title.
        _sessionSnapshots.putIfAbsent(sessionId, _SessionSnapshot.new).title = title;
        return [
          BridgeSseSessionUpdated(info: _sessionUpdate(sessionId, title).toJson()),
        ];
    }

    // Dropped intentionally: current_mode_update (the mode is surfaced as the
    // session "variant", driven by the plugin, not a message event), and any
    // future standard variants the mobile UI has no renderer for.
    return const [];
  }

  /// Hook for non-`session/update` notifications (harness extensions such as
  /// Cursor's `cursor/update_todos`). Base implementation drops them.
  List<BridgeSseEvent> mapExtension(AcpNotification notification) => const [];

  List<BridgeSseEvent> _textChunk({
    required String sessionId,
    required Map<String, dynamic> update,
    required _ChunkRole role,
    required String partSuffix,
    required PluginMessagePartType partType,
  }) {
    final text = acpContentText(update["content"]);
    if (text == null || text.isEmpty) return const [];

    // ACP v1: chunks of one message share a `messageId`; a change starts a new
    // message. Group by it when present, so an agent emitting several same-role
    // messages in one turn doesn't collapse them into one sesori message. The
    // role stays in the id so a pathological cross-role id reuse can't merge a
    // user chunk into an assistant envelope. Absent (Cursor today) → the
    // synthesized per-turn id.
    final acpMessageId = update["messageId"];
    final messageId = acpMessageId is String && acpMessageId.isNotEmpty
        ? "$sessionId-m$acpMessageId-${role.name}"
        : "$sessionId-t${_turn(sessionId)}-${role.name}";
    final partId = "$messageId-$partSuffix";

    final events = <BridgeSseEvent>[];
    final started = _startedParts.putIfAbsent(sessionId, () => <String>{});
    if (started.add(partId)) {
      events.add(
        BridgeSseMessageUpdated(info: _messageFor(role, messageId, sessionId).toJson()),
      );
      events.add(
        BridgeSseMessagePartUpdated(
          part: _part(
            partId: partId,
            messageId: messageId,
            sessionId: sessionId,
            type: partType,
            text: "",
          ),
        ),
      );
    }
    events.add(
      BridgeSseMessagePartDelta(
        sessionID: sessionId,
        messageID: messageId,
        partID: partId,
        field: "text",
        delta: text,
      ),
    );
    return events;
  }

  List<BridgeSseEvent> _toolCall({
    required String sessionId,
    required Map<String, dynamic> update,
  }) {
    final toolCallId = update["toolCallId"] as String?;
    if (toolCallId == null || toolCallId.isEmpty) return const [];
    final messageId = "$sessionId-tool-$toolCallId";
    final state = _LiveTool(
      // Fail-soft like the tool name and `_toolCallUpdate`'s title: a non-string
      // title (schema drift / malformed agent data) renders as null rather than
      // throwing and aborting the notification.
      tool: acpToolName(update),
      title: update["title"] is String ? update["title"] as String? : null,
      status: acpToolStatus(update["status"]),
      output: acpToolOutputText(update),
    );
    (_liveTools[sessionId] ??= {})[toolCallId] = state;
    return [
      _toolEnvelope(sessionId: sessionId, messageId: messageId),
      _toolPartEvent(sessionId: sessionId, messageId: messageId, state: state),
      // An agent may report the whole mutation as one complete initial
      // `tool_call` (no follow-up update), so the diff signal must fire here
      // too, mirroring `_toolCallUpdate`.
      if (_isFileMutation(update)) BridgeSseSessionDiff(sessionID: sessionId),
    ];
  }

  List<BridgeSseEvent> _toolCallUpdate({
    required String sessionId,
    required Map<String, dynamic> update,
  }) {
    final toolCallId = update["toolCallId"] as String?;
    if (toolCallId == null || toolCallId.isEmpty) return const [];
    final messageId = "$sessionId-tool-$toolCallId";
    // A `tool_call_update` is a PARTIAL update: an agent may send only the
    // changed fields (e.g. `{status: completed}`). Merge onto the tool's prior
    // state so an omitted name/title/output/status isn't reset to a default,
    // which would blank an existing tool card. Mirrors the replay collector,
    // which already merges — keeping live and history renderings consistent.
    final prior = _liveTools[sessionId]?[toolCallId];
    // Only re-resolve the tool identifier when `kind` is explicitly present; a
    // title-only update must NOT overwrite the canonical id (e.g. "edit") with
    // the title text (`title` lives separately in PluginToolState.title). This
    // matches the replay collector, which preserves the original tool name.
    final hasKind = update["kind"] is String && (update["kind"] as String).isNotEmpty;
    final newOutput = acpToolOutputText(update);
    final state = _LiveTool(
      tool: hasKind ? acpToolName(update) : (prior?.tool ?? acpToolName(update)),
      title: update.containsKey("title") && update["title"] is String
          ? update["title"] as String?
          : prior?.title,
      status: update.containsKey("status") ? acpToolStatus(update["status"]) : (prior?.status ?? PluginToolStatus.pending),
      output: newOutput ?? prior?.output,
    );
    final events = <BridgeSseEvent>[
      // ACP events can be reordered (reconnect / resume / replay), so a
      // `tool_call_update` may arrive before its `tool_call`. When it is
      // first-seen, synthesize the message envelope — like `_textChunk` does —
      // so the client can render the part instead of receiving an orphan it
      // drops.
      if (prior == null) _toolEnvelope(sessionId: sessionId, messageId: messageId),
      _toolPartEvent(sessionId: sessionId, messageId: messageId, state: state),
    ];
    // Retained (not pruned on terminal) so a late reordered update still merges
    // onto the terminal state; bounded by the [beginTurn] / [forgetSession]
    // clears.
    (_liveTools[sessionId] ??= {})[toolCallId] = state;
    if (_isFileMutation(update)) {
      events.add(BridgeSseSessionDiff(sessionID: sessionId));
    }
    return events;
  }

  BridgeSseMessageUpdated _toolEnvelope({required String sessionId, required String messageId}) {
    return BridgeSseMessageUpdated(
      info: shared.Message.assistant(
        id: messageId,
        sessionID: sessionId,
        agent: agentId,
        modelID: modelForSession(sessionId),
        providerID: providerForSession(sessionId),
        // ACP carries no per-message timestamps; the mobile model treats a null
        // time as "unknown".
        time: null,
      ).toJson(),
    );
  }

  BridgeSseMessagePartUpdated _toolPartEvent({
    required String sessionId,
    required String messageId,
    required _LiveTool state,
  }) {
    return BridgeSseMessagePartUpdated(
      part: _toolPart(
        partId: "$messageId-call",
        messageId: messageId,
        sessionId: sessionId,
        tool: state.tool,
        state: PluginToolState(
          status: state.status,
          title: state.title,
          output: state.output,
          error: state.status == PluginToolStatus.error ? state.output : null,
        ),
      ),
    );
  }

  shared.Message _messageFor(_ChunkRole role, String messageId, String sessionId) {
    return switch (role) {
      _ChunkRole.user => shared.Message.user(
        id: messageId,
        sessionID: sessionId,
        agent: null,
        time: null,
      ),
      _ChunkRole.assistant => shared.Message.assistant(
        id: messageId,
        sessionID: sessionId,
        agent: agentId,
        modelID: modelForSession(sessionId),
        providerID: providerForSession(sessionId),
        time: null,
      ),
    };
  }

  /// The [shared.Session] emitted for a `session_info_update`. The mobile list
  /// handler REPLACES the whole session on `session.updated`, so beyond the id
  /// and new title this must carry the best-known `time` — a null time would
  /// drop the row's sort position to epoch 0 until a full refresh whenever no
  /// stored bridge row exists to enrich from (creation race, never-persisted
  /// historical session). Times come from the plugin-fed snapshot (see
  /// [setSessionSnapshot]); with no snapshot at all, time stays null.
  shared.Session _sessionUpdate(String id, String? title) {
    final project = projectForSession(id);
    final snapshot = _sessionSnapshots[id];
    final created = snapshot?.createdMs;
    final updated = snapshot?.updatedMs ?? created;
    return shared.Session(
      id: id,
      projectID: project,
      directory: project,
      parentID: null,
      title: title,
      time: created == null && updated == null
          ? null
          : shared.SessionTime(
              created: created ?? updated!,
              updated: updated ?? created!,
              archived: null,
            ),
      summary: null,
      pullRequest: null,
      promptDefaults: null,
    );
  }

  /// Parses an `available_commands_update` payload's `availableCommands` list
  /// fail-soft: a malformed entry is skipped rather than dropping the batch.
  static List<PluginCommand> _parseAvailableCommands(Object? raw) {
    if (raw is! List) return const [];
    final commands = <PluginCommand>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final name = map["name"];
      if (name is! String || name.isEmpty) continue;
      final description = map["description"];
      final input = map["input"];
      final hint = input is Map ? input["hint"] : null;
      commands.add(
        PluginCommand(
          name: name,
          description: description is String && description.isNotEmpty ? description : null,
          hints: [if (hint is String && hint.isNotEmpty) hint],
          provider: null,
          source: PluginCommandSource.command,
        ),
      );
    }
    return commands;
  }

  /// Lenient timestamp: the spec sends ISO 8601 strings, live agents have
  /// shipped epoch numbers — accept both, anything else is null.
  static int? _timestampMs(Object? raw) {
    if (raw is num) return raw.round();
    if (raw is String) return DateTime.tryParse(raw)?.millisecondsSinceEpoch;
    return null;
  }

  PluginMessagePart _part({
    required String partId,
    required String messageId,
    required String sessionId,
    required PluginMessagePartType type,
    required String text,
  }) {
    return PluginMessagePart(
      id: partId,
      sessionID: sessionId,
      messageID: messageId,
      type: type,
      text: text,
      tool: null,
      state: null,
      prompt: null,
      description: null,
      agent: null,
      agentName: null,
      attempt: null,
      retryError: null,
    );
  }

  PluginMessagePart _toolPart({
    required String partId,
    required String messageId,
    required String sessionId,
    required String tool,
    required PluginToolState state,
  }) {
    return PluginMessagePart(
      id: partId,
      sessionID: sessionId,
      messageID: messageId,
      type: PluginMessagePartType.tool,
      text: null,
      tool: tool,
      state: state,
      prompt: null,
      description: null,
      agent: null,
      agentName: null,
      attempt: null,
      retryError: null,
    );
  }

  /// Whether a `tool_call`/`tool_call_update` payload reports a file mutation:
  /// a mutating `kind`, or a standard tool `content` entry of `type: "diff"`
  /// (a spec-compliant agent may report an edit only through the diff content
  /// shape, with a non-mutating or absent kind).
  bool _isFileMutation(Map<String, dynamic> update) {
    final kind = update["kind"];
    if (kind == "edit" || kind == "delete" || kind == "move") return true;
    final content = update["content"];
    if (content is List) {
      for (final entry in content) {
        if (entry is Map && entry["type"] == "diff") return true;
      }
    }
    return false;
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }
}

enum _ChunkRole { user, assistant }

/// Last-known metadata for one session (title, times), merged into the
/// `session.updated` payload a `session_info_update` emits.
class _SessionSnapshot {
  String? title;
  int? createdMs;
  int? updatedMs;
}

/// The last-rendered state of one live tool call, so a partial
/// `tool_call_update` merges onto it instead of replacing it.
class _LiveTool {
  _LiveTool({
    required this.tool,
    required this.title,
    required this.status,
    required this.output,
  });

  final String tool;
  final String? title;
  final PluginToolStatus status;
  final String? output;
}
