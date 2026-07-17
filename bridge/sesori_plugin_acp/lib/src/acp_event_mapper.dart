import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "repositories/models/acp_notification_record.dart";

/// A backend "halt notice": the agent ended a turn without doing the requested
/// work and instead streamed a terminal notice telling the user to change
/// something (account, plan, model, or settings). Cursor's account/plan gate
/// ("Check your settings to continue") is the canonical case.
///
/// On the wire such a notice is an ordinary `agent_message_chunk` ending with
/// `stopReason: end_turn` — indistinguishable from real assistant prose — so a
/// backend that knows its own gate wording recognizes it (see
/// [AcpEventMapper.classifyHaltNotice]) and it is surfaced as a
/// [shared.Message.error] instead of quiet assistant text, giving the user an
/// explicit "the turn did not run" signal.
class AcpHaltNotice {
  const AcpHaltNotice({required this.errorName, required this.message});

  /// Short stable label for the halt class (e.g. "cursor_gate"), carried in
  /// the error message's `errorName`.
  final String errorName;

  /// The user-facing notice text to show (the agent's own wording).
  final String message;
}

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
  AcpEventMapper({required String launchDirectory, required this.agentId, required this.pluginId})
    : launchDirectory = normalizeProjectDirectory(directory: launchDirectory);

  /// The bridge launch directory (canonicalized) — the fallback project
  /// attribution for sessions whose own directory is not (yet) known. Matches
  /// the canonical project id the bridge derives for the same directory.
  final String launchDirectory;

  /// Agent name stamped on assistant messages (e.g. "cursor").
  final String agentId;

  final String pluginId;

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
  String? modelForSession(String sessionId) => _sessionModel[sessionId] ?? currentModelId;
  String? providerForSession(String sessionId) => _sessionProvider[sessionId] ?? currentProviderId;

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
    if (updatedMs != null) {
      final prior = snapshot.updatedMs;
      snapshot.updatedMs = prior == null || updatedMs > prior ? updatedMs : prior;
    }
  }

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
  String projectForSession(String sessionId) => _sessionProject[sessionId] ?? launchDirectory;

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
    _sentUserSeq.remove(sessionId);
    _idlessAssistantSeq.remove(sessionId);
    _openIdlessAssistant.remove(sessionId);
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

  /// Sequence for user messages accepted by this plugin. These are emitted
  /// locally because ACP agents do not reliably echo `user_message_chunk`.
  final Map<String, int> _sentUserSeq = {};

  /// Fallback assistant-envelope sequence when ACP omits `messageId`.
  final Map<String, int> _idlessAssistantSeq = {};

  /// Sessions whose current id-less assistant envelope has received content.
  final Set<String> _openIdlessAssistant = {};

  /// Advance the turn counter for [sessionId]. Call before `session/prompt`
  /// so the next batch of streamed chunks groups under a fresh message id.
  void beginTurn(String sessionId) {
    _turnSeq[sessionId] = (_turnSeq[sessionId] ?? 0) + 1;
    // The new turn uses fresh (turn-numbered) part ids, so the prior turn's are
    // dead weight — drop them to bound memory in long sessions.
    _startedParts.remove(sessionId);
    _idlessAssistantSeq.remove(sessionId);
    _openIdlessAssistant.remove(sessionId);
    // Tool state is retained across a turn (so a reordered late `tool_call_update`
    // still merges onto its terminal state instead of blanking the card), and
    // cleared here at the turn boundary to keep it bounded.
    _liveTools.remove(sessionId);
  }

  int _turn(String sessionId) => _turnSeq[sessionId] ?? 1;

  /// Maps an accepted outbound prompt to its canonical live user message.
  List<BridgeSseEvent> mapSentPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
  }) {
    final textParts = parts.whereType<PluginPromptPartText>().where((part) => part.text.isNotEmpty).toList();
    if (textParts.isEmpty) return const [];

    final sequence = (_sentUserSeq[sessionId] ?? 0) + 1;
    _sentUserSeq[sessionId] = sequence;
    final messageId = "$sessionId-sent-$sequence-user";
    return [
      BridgeSseMessageUpdated(
        info: _messageFor(_ChunkRole.user, messageId, sessionId).toJson(),
      ),
      for (var index = 0; index < textParts.length; index++)
        BridgeSseMessagePartUpdated(
          part: _part(
            partId: "$messageId-text-$index",
            messageId: messageId,
            sessionId: sessionId,
            type: PluginMessagePartType.text,
            text: textParts[index].text,
          ),
        ),
    ];
  }

  /// Maps one repository-owned notification record to bridge events.
  List<BridgeSseEvent> map(AcpNotificationRecord notification) {
    return switch (notification) {
      AcpExtensionNotificationRecord() => mapExtension(notification),
      AcpMessageChunkRecord() => _messageChunk(notification),
      AcpToolUpdateRecord(:final isInitial) => isInitial ? _toolCall(notification) : _toolCallUpdate(notification),
      AcpPlanChangedRecord() => _planChanged(notification),
      AcpAvailableCommandsChangedRecord() => _availableCommandsChanged(
        notification,
      ),
      AcpSessionInfoChangedRecord() => _sessionInfoChanged(notification),
      AcpIgnoredSessionNotificationRecord() => const [],
    };
  }

  /// Hook for non-`session/update` notifications (harness extensions such as
  /// Cursor's `cursor/update_todos`). Base implementation drops them.
  List<BridgeSseEvent> mapExtension(AcpExtensionNotificationRecord notification) => const [];

  List<BridgeSseEvent> _messageChunk(AcpMessageChunkRecord notification) {
    return switch (notification.role) {
      AcpMessageChunkRole.user => const [],
      AcpMessageChunkRole.assistant => _textChunk(
        sessionId: notification.sessionId,
        acpMessageId: notification.messageId,
        text: notification.text,
        role: _ChunkRole.assistant,
        partSuffix: "text",
        partType: PluginMessagePartType.text,
      ),
      AcpMessageChunkRole.thought => _textChunk(
        sessionId: notification.sessionId,
        acpMessageId: notification.messageId,
        text: notification.text,
        role: _ChunkRole.assistant,
        partSuffix: "reasoning",
        partType: PluginMessagePartType.reasoning,
      ),
    };
  }

  List<BridgeSseEvent> _planChanged(AcpPlanChangedRecord notification) => [
    BridgeSseTodoUpdated(sessionID: notification.sessionId),
  ];

  List<BridgeSseEvent> _availableCommandsChanged(
    AcpAvailableCommandsChangedRecord notification,
  ) => [
    BridgeSseSessionsUpdated(
      sessionID: notification.sessionId,
      projectID: projectForSession(notification.sessionId),
    ),
  ];

  List<BridgeSseEvent> _sessionInfoChanged(
    AcpSessionInfoChangedRecord notification,
  ) => _sessionInfoEvents(
    sessionId: notification.sessionId,
    hasTitle: notification.hasTitle,
    title: notification.title,
    updatedAtMs: notification.updatedAtMs,
  );

  /// Hook: classify an assistant message's [text] as a backend halt notice
  /// (see [AcpHaltNotice]) — the agent ended the turn without doing the
  /// requested work and told the user to change something. Returns the notice
  /// to surface as an error message, or null for ordinary assistant prose.
  ///
  /// Invoked with two text shapes: live, [text] is a single `agent_message_chunk`
  /// (which equals the whole message only because the notice is emitted as one
  /// atomic chunk); on history replay, [text] is the fully-accumulated message
  /// text. An override that must gate on the complete message (e.g. a backend
  /// that splits its notice across chunks) has to account for the live per-chunk
  /// shape.
  ///
  /// Base backends never halt this way; harness subclasses that emit
  /// recognizable gate text (e.g. Cursor) override this. Also consulted by the
  /// history-replay collector so a reloaded session renders the notice the same
  /// way it did live.
  AcpHaltNotice? classifyHaltNotice({required String text}) => null;

  List<BridgeSseEvent> _textChunk({
    required String sessionId,
    required String? acpMessageId,
    required String? text,
    required _ChunkRole role,
    required String partSuffix,
    required PluginMessagePartType partType,
  }) {
    if (text == null || text.isEmpty) return const [];

    // A backend may end a turn without doing the requested work and instead
    // emit a terminal "halt" notice as an ordinary assistant message (Cursor's
    // account/plan gates: "Check your settings to continue"). Only a message
    // chunk can be such a notice, never a reasoning chunk. A recognized notice
    // is surfaced as an explicit error message so the user sees the turn did not
    // run, rather than a quiet line of assistant text. Cursor emits the notice
    // as one atomic chunk; a hypothetically split notice falls through to plain
    // text (no regression).
    if (partType == PluginMessagePartType.text) {
      final halt = classifyHaltNotice(text: text);
      if (halt != null) return _haltNoticeEvents(sessionId: sessionId, notice: halt);
    }

    // ACP v1: chunks of one message share a `messageId`; a change starts a new
    // message. Group by it when present, so an agent emitting several same-role
    // messages in one turn doesn't collapse them into one sesori message. The
    // role stays in the id so a pathological cross-role id reuse can't merge a
    // user chunk into an assistant envelope. Absent (Cursor today) → the
    // synthesized per-turn id.
    final hasAcpMessageId = acpMessageId != null;
    final fallbackSuffix = role == _ChunkRole.assistant ? "-a${_idlessAssistantSeq[sessionId] ?? 0}" : "";
    final messageId = hasAcpMessageId
        ? "$sessionId-m$acpMessageId-${role.name}"
        : "$sessionId-t${_turn(sessionId)}-${role.name}$fallbackSuffix";
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
    if (role == _ChunkRole.assistant && !hasAcpMessageId) {
      _openIdlessAssistant.add(sessionId);
    }
    return events;
  }

  /// Emits a backend halt [notice] (see [classifyHaltNotice]) as a single
  /// error message so the client renders it with its explicit error card
  /// instead of quiet assistant prose. The notice text rides in the error
  /// message itself, so no separate part is needed. Deduped per turn: a
  /// repeated identical chunk must not stack duplicate error cards.
  List<BridgeSseEvent> _haltNoticeEvents({
    required String sessionId,
    required AcpHaltNotice notice,
  }) {
    final messageId = "$sessionId-t${_turn(sessionId)}-halt";
    final started = _startedParts.putIfAbsent(sessionId, () => <String>{});
    if (!started.add(messageId)) return const [];
    // Any id-less assistant envelope opened earlier this turn is abandoned: the
    // halt notice is the turn's outcome and stands alone. Closing it bumps the
    // fallback sequence, so a later reordered id-less chunk recomputes a fresh
    // message id and opens a new envelope rather than appending a delta to the
    // abandoned one. (The dedupe return above runs first, so a repeated halt
    // chunk can't double-bump the sequence.)
    _closeIdlessAssistantEnvelope(sessionId);
    return [
      BridgeSseMessageUpdated(
        info: shared.Message.error(
          id: messageId,
          sessionID: sessionId,
          agent: agentId,
          modelID: modelForSession(sessionId),
          providerID: providerForSession(sessionId),
          errorName: notice.errorName,
          errorMessage: notice.message,
          time: null,
        ).toJson(),
      ),
    ];
  }

  List<BridgeSseEvent> _toolCall(AcpToolUpdateRecord update) {
    final sessionId = update.sessionId;
    final toolCallId = update.toolCallId;
    if (toolCallId == null || toolCallId.isEmpty) return const [];
    if (_liveTools[sessionId]?[toolCallId] == null) {
      _closeIdlessAssistantEnvelope(sessionId);
    }
    final messageId = "$sessionId-tool-$toolCallId";
    final state = _LiveTool(
      tool: update.toolName,
      title: update.title,
      status: update.status,
      output: update.output,
      isFileMutation: update.isFileMutation,
      diffEmitted: false,
    );
    (_liveTools[sessionId] ??= {})[toolCallId] = state;
    final events = <BridgeSseEvent>[
      _toolEnvelope(sessionId: sessionId, messageId: messageId),
      _toolPartEvent(sessionId: sessionId, messageId: messageId, state: state),
    ];
    _appendCompletedMutationDiff(
      events: events,
      sessionId: sessionId,
      state: state,
      mutationAvailable: update.hasDiff,
    );
    return events;
  }

  List<BridgeSseEvent> _toolCallUpdate(AcpToolUpdateRecord update) {
    final sessionId = update.sessionId;
    final toolCallId = update.toolCallId;
    if (toolCallId == null || toolCallId.isEmpty) return const [];
    final messageId = "$sessionId-tool-$toolCallId";
    // A `tool_call_update` is a PARTIAL update: an agent may send only the
    // changed fields (e.g. `{status: completed}`). Merge onto the tool's prior
    // state so an omitted name/title/output/status isn't reset to a default,
    // which would blank an existing tool card. Mirrors the replay collector,
    // which already merges — keeping live and history renderings consistent.
    final prior = _liveTools[sessionId]?[toolCallId];
    if (prior == null) {
      _closeIdlessAssistantEnvelope(sessionId);
    }
    // Only re-resolve the tool identifier when `kind` is explicitly present; a
    // title-only update must NOT overwrite the canonical id (e.g. "edit") with
    // the title text (`title` lives separately in PluginToolState.title). This
    // matches the replay collector, which preserves the original tool name.
    final state = _LiveTool(
      tool: update.hasKind ? update.toolName : (prior?.tool ?? update.toolName),
      title: update.hasTitle ? update.title : prior?.title,
      status: update.hasStatus ? update.status : (prior?.status ?? PluginToolStatus.pending),
      output: update.output ?? prior?.output,
      isFileMutation: (prior?.isFileMutation ?? false) || update.isFileMutation,
      diffEmitted: prior?.diffEmitted ?? false,
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
    _appendCompletedMutationDiff(
      events: events,
      sessionId: sessionId,
      state: state,
      mutationAvailable: update.hasDiff,
    );
    return events;
  }

  void _closeIdlessAssistantEnvelope(String sessionId) {
    if (!_openIdlessAssistant.remove(sessionId)) return;
    _idlessAssistantSeq[sessionId] = (_idlessAssistantSeq[sessionId] ?? 0) + 1;
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
  shared.Session _sessionUpdate(String id) {
    final project = projectForSession(id);
    final snapshot = _sessionSnapshots[id];
    final created = snapshot?.createdMs;
    final updated = snapshot?.updatedMs ?? created;
    return shared.Session(
      id: id,
      pluginId: pluginId,
      projectID: project,
      directory: project,
      parentID: null,
      title: snapshot?.title,
      time: created == null && updated == null
          ? null
          : shared.SessionTime(
              created: created ?? updated!,
              updated: updated ?? created!,
              archived: null,
            ),
      pullRequest: null,
      promptDefaults: null,
    );
  }

  List<BridgeSseEvent> _sessionInfoEvents({
    required String sessionId,
    required bool hasTitle,
    required String? title,
    required int? updatedAtMs,
  }) {
    if (updatedAtMs != null) {
      setSessionSnapshot(
        sessionId: sessionId,
        title: null,
        createdMs: null,
        updatedMs: updatedAtMs,
      );
    }
    if (hasTitle) {
      _sessionSnapshots.putIfAbsent(sessionId, _SessionSnapshot.new).title = title;
    }
    if (!hasTitle && updatedAtMs == null) return const [];
    return [
      BridgeSseSessionUpdated(
        info: _sessionUpdate(sessionId).toJson(),
        titleChanged: hasTitle,
      ),
    ];
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

  void _appendCompletedMutationDiff({
    required List<BridgeSseEvent> events,
    required String sessionId,
    required _LiveTool state,
    required bool mutationAvailable,
  }) {
    if (!state.isFileMutation || state.diffEmitted) {
      return;
    }
    if (!mutationAvailable && !_isTerminalToolStatus(state.status)) {
      return;
    }
    state.diffEmitted = true;
    events.add(BridgeSseSessionDiff(sessionID: sessionId));
  }

  bool _isTerminalToolStatus(PluginToolStatus status) {
    return switch (status) {
      PluginToolStatus.completed || PluginToolStatus.error => true,
      PluginToolStatus.pending || PluginToolStatus.running || PluginToolStatus.unknown => false,
    };
  }
}

enum _ChunkRole { user, assistant }

/// Last-known metadata for one session, merged into the `session.updated`
/// payload a `session_info_update` emits.
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
    required this.isFileMutation,
    required this.diffEmitted,
  });

  final String tool;
  final String? title;
  final PluginToolStatus status;
  final String? output;
  final bool isFileMutation;
  bool diffEmitted;
}
