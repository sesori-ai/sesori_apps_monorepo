import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "acp_protocol.dart";
import "acp_session_configuration_tracker.dart";
import "acp_stdio_client.dart";
import "repositories/mappers/acp_content_mapper.dart";
import "repositories/trackers/acp_child_session_tracker.dart";
import "repositories/trackers/acp_content_tracker.dart";
import "repositories/trackers/acp_tool_content_tracker.dart";

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
/// explicit "the turn did not run" signal. Classification carries no replacement
/// message; the mapper always forwards the original backend text unchanged.
class const AcpHaltNotice({
  /// Short stable label for the halt class (e.g. "cursor_gate"), carried in
  /// the error message's `errorName`.
  required final String errorName,
});

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
class AcpEventMapper({
  required String launchDirectory,

  /// The owning plugin's id — also the `agent` stamped on every message this
  /// mapper emits (the cross-plugin convention: codex stamps "codex", pi its
  /// plugin id), and what history replay must stamp to match the live stream.
  required final String pluginId,
  required final AcpSessionConfigurationTracker _configurationTracker,

  /// The composition-owned child-session tracker shared with the plugin. The
  /// mapper only pushes lifecycle facts into it (see [mapChildSpawned] and
  /// [mapChildFinished]); the plugin reads its snapshots and clears it.
  required final AcpChildSessionTracker childSessions,
}) {
  static const AcpContentMapper _contentMapper = AcpContentMapper();

  /// The bridge launch directory (canonicalized) — the fallback project
  /// attribution for sessions whose own directory is not (yet) known. Matches
  /// the canonical project id the bridge derives for the same directory.
  final String launchDirectory = normalizeProjectDirectory(directory: launchDirectory);

  /// The model/provider to stamp on [sessionId]'s assistant messages.
  String? modelForSession({required String sessionId}) =>
      _configurationTracker.snapshotForSession(sessionId: sessionId).modelId;
  String? providerForSession({required String sessionId}) =>
      _configurationTracker.snapshotForSession(sessionId: sessionId).providerId;

  /// Backend extension time for a message-bearing ACP notification.
  PluginMessageTime? messageTimeForNotification({required AcpNotification notification}) => null;

  /// Backend-authoritative time for a locally projected accepted user message.
  PluginMessageTime? localUserMessageTime({required int createdAtMs}) => null;

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

  /// Advances session recency for accepted outbound work. ACP agents do not
  /// consistently emit a timestamp-bearing `session_info_update`, so the
  /// plugin supplies its acceptance time while preserving strict monotonicity.
  BridgeSseSessionUpdated mapSessionActivity({
    required String sessionId,
    required int updatedAtMs,
  }) {
    final snapshot = _sessionSnapshots[sessionId];
    final previousUpdatedMs = snapshot?.updatedMs ?? snapshot?.createdMs;
    final nextUpdatedMs = previousUpdatedMs == null || updatedAtMs > previousUpdatedMs
        ? updatedAtMs
        : previousUpdatedMs + 1;
    setSessionSnapshot(
      sessionId: sessionId,
      title: null,
      createdMs: null,
      updatedMs: nextUpdatedMs,
    );
    return BridgeSseSessionUpdated(
      info: _sessionUpdate(sessionId).toJson(),
      titleChanged: false,
    );
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
  String projectForSession({required String sessionId}) => _sessionProject[sessionId] ?? launchDirectory;

  /// Drops every per-session cache entry for [sessionId] — called when the
  /// session is deleted so live-render state (model, project, turn counters,
  /// started parts, live tools) doesn't accumulate across a long-lived process.
  void forgetSession(String sessionId) {
    _sessionProject.remove(sessionId);
    _sessionSnapshots.remove(sessionId);
    _turnSeq.remove(sessionId);
    _turnMessageIds.remove(sessionId);
    _startedParts.remove(sessionId);
    _contentTrackers.remove(sessionId);
    _textPartAccumulators.remove(sessionId);
    _idlessAssistantSeq.remove(sessionId);
    _openIdlessAssistant.remove(sessionId);
    // Exact per-session removal — session ids are opaque agent strings that may
    // themselves contain ':', so a prefix match on a composite key could wipe a
    // different session's tools.
    _liveTools.remove(sessionId);
    _spawnToolCalls.remove(sessionId);
  }

  /// sessionId -> tool-call ids the harness classified as sub-agent spawns
  /// (see [isSubagentSpawnToolCall]). Their tool card is never rendered: the
  /// tile comes from the harness's lifecycle notification, keyed by the child
  /// id, so a spawn that reports no shared id still yields exactly one tile.
  /// Bounded like [_liveTools]: cleared per turn and on [forgetSession].
  final Map<String, Set<String>> _spawnToolCalls = {};

  /// sessionId -> (toolCallId -> last-rendered live tool state). ACP
  /// `tool_call_update` notifications are partial, so this preserves the tool's
  /// name/title/status/content across updates that omit them. Nested (not a
  /// composite "sessionId:toolCallId" key) so cleanup is exact regardless of
  /// characters in the opaque agent-supplied ids.
  final Map<String, Map<String, _LiveTool>> _liveTools = {};

  /// Resolves the live session that owns [toolCallId], when a harness extension
  /// omits `sessionId` but carries the originating tool call id.
  String? sessionIdForToolCallId({required String? toolCallId}) {
    if (toolCallId == null || toolCallId.isEmpty) return null;
    for (final entry in _liveTools.entries) {
      if (entry.value.containsKey(toolCallId)) return entry.key;
    }
    for (final entry in _spawnToolCalls.entries) {
      if (entry.value.contains(toolCallId)) return entry.key;
    }
    return null;
  }

  /// sessionId -> current turn number, advanced by [beginTurn].
  final Map<String, int> _turnSeq = {};

  /// Stable user-message identity for the current dispatched turn. Unlike the
  /// process-local turn counter, this survives an agent or bridge restart via
  /// the client's prompt id and cannot overwrite an earlier id-less reply.
  final Map<String, String> _turnMessageIds = {};

  /// Per-session part ids whose envelope/part has already been emitted in the
  /// current turn. Scoped per session and pruned on [beginTurn] so it cannot
  /// grow without bound across a long-running session.
  final Map<String, Set<String>> _startedParts = {};

  /// Per-session, per-message ordered content state. Nested keys keep cleanup
  /// exact for opaque session and ACP message identifiers.
  final Map<String, Map<String, AcpContentTracker>> _contentTrackers = {};

  /// Text accumulated from ACP deltas until the serialized prompt turn settles.
  /// ACP emits an empty part snapshot followed by deltas, while chat history
  /// persists complete part snapshots only.
  final Map<String, Map<String, _TextPartAccumulator>> _textPartAccumulators = {};

  /// Fallback assistant-envelope sequence when ACP omits `messageId`.
  final Map<String, int> _idlessAssistantSeq = {};

  /// Sessions whose current id-less assistant envelope has received content.
  final Set<String> _openIdlessAssistant = {};

  /// Advance the turn counter for [sessionId]. Call before `session/prompt`
  /// so the next batch of streamed chunks groups under a fresh message id.
  /// [messageId] is the accepted user-message identity and keeps fallback ACP
  /// assistant ids unique when a new mapper starts for an existing session.
  void beginTurn({required String sessionId, required String? messageId}) {
    _turnSeq[sessionId] = (_turnSeq[sessionId] ?? 0) + 1;
    if (messageId == null) {
      _turnMessageIds.remove(sessionId);
    } else {
      _turnMessageIds[sessionId] = messageId;
    }
    // The new turn uses fresh (turn-numbered) part ids, so the prior turn's are
    // dead weight — drop them to bound memory in long sessions.
    _startedParts.remove(sessionId);
    _contentTrackers.remove(sessionId);
    _textPartAccumulators.remove(sessionId);
    _idlessAssistantSeq.remove(sessionId);
    _openIdlessAssistant.remove(sessionId);
    // Tool state is retained across a turn (so a reordered late `tool_call_update`
    // still merges onto its terminal state instead of blanking the card), and
    // cleared here at the turn boundary to keep it bounded.
    _liveTools.remove(sessionId);
    _spawnToolCalls.remove(sessionId);
  }

  /// Maps a rejected `session/prompt` into a durable inline error. A session
  /// error event carries no diagnostic text, so emitting only that event would
  /// make an accepted prompt appear to finish silently.
  BridgeSseMessageUpdated mapPromptError({
    required String sessionId,
    required String message,
  }) => BridgeSseMessageUpdated(
    info: shared.Message.error(
      id: "${_fallbackTurnMessageId(sessionId)}-error",
      sessionID: sessionId,
      agent: pluginId,
      modelID: modelForSession(sessionId: sessionId),
      providerID: providerForSession(sessionId: sessionId),
      errorName: "ACP prompt failed",
      errorMessage: message,
      time: null,
    ).toJson(),
  );

  /// Emits complete snapshots for text and reasoning parts streamed during the
  /// current turn. The caller owns the turn boundary and must call this before
  /// the next turn starts.
  List<BridgeSseEvent> finalizeTurn({required String sessionId}) {
    final accumulators = _textPartAccumulators.remove(sessionId);
    if (accumulators == null) return const [];

    return [
      for (final accumulator in accumulators.values)
        if (accumulator.type != PluginMessagePartType.reasoning || accumulator.isStreaming)
          BridgeSseMessagePartUpdated(
            part: _part(
              partId: accumulator.partId,
              messageId: accumulator.messageId,
              sessionId: sessionId,
              type: accumulator.type,
              text: accumulator.text.toString(),
              attachment: null,
            ),
          ),
    ];
  }

  int _turn(String sessionId) => _turnSeq[sessionId] ?? 1;

  String _fallbackTurnMessageId(String sessionId) => _turnMessageIds[sessionId] ?? "$sessionId-t${_turn(sessionId)}";

  static String initialUserMessageId(String sessionId) => "$sessionId-initial-user";

  /// Maps the user-authored portion of a creation prompt with an identity that
  /// the same-process history replay can reuse. Matching message and part ids
  /// let the client upsert either arrival order instead of rendering both.
  List<BridgeSseEvent> mapInitialPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required int createdAtMs,
  }) => _mapUserPrompt(
    sessionId: sessionId,
    messageId: initialUserMessageId(sessionId),
    promptId: null,
    parts: parts,
    time: localUserMessageTime(createdAtMs: createdAtMs),
  );

  /// Derives the durable user-message identity from the accepted prompt id.
  static String sentUserMessageId({required String promptId}) => "$promptId-user";

  /// Maps an accepted outbound prompt to its canonical live user message.
  List<BridgeSseEvent> mapSentPrompt({
    required String sessionId,
    required String messageId,
    required String promptId,
    required List<PluginPromptPart> parts,
    required int createdAtMs,
  }) => _mapUserPrompt(
    sessionId: sessionId,
    messageId: messageId,
    promptId: promptId,
    parts: parts,
    time: localUserMessageTime(createdAtMs: createdAtMs),
  );

  List<BridgeSseEvent> _mapUserPrompt({
    required String sessionId,
    required String messageId,
    required String? promptId,
    required List<PluginPromptPart> parts,
    required PluginMessageTime? time,
  }) {
    final content = <Map<String, dynamic>>[
      for (final part in parts)
        switch (part) {
          PluginPromptPartText(:final text) => {"type": "text", "text": text},
          PluginPromptPartFileData(:final mime, :final base64) => {
            "type": "image",
            "mimeType": mime,
            "data": base64,
          },
          PluginPromptPartFilePath() || PluginPromptPartFileUrl() => const {},
        },
    ];
    final tracker = AcpContentTracker();
    final mutations = tracker.append(
      blocks: _contentMapper.mapScoped(
        content: content.where((block) => block.isNotEmpty).toList(growable: false),
        scope: tracker.mappingScope,
      ),
    );
    if (mutations.isEmpty) return const [];
    return [
      BridgeSseMessageUpdated(
        info: _messageFor(_ChunkRole.user, messageId, sessionId, promptId: promptId, time: time).toJson(),
      ),
      for (final mutation in mutations)
        BridgeSseMessagePartUpdated(
          part: switch (mutation) {
            AcpTextDeltaMutation(:final partIdSuffix, :final delta) => _part(
              partId: "$messageId-$partIdSuffix",
              messageId: messageId,
              sessionId: sessionId,
              type: PluginMessagePartType.text,
              text: delta,
              attachment: null,
            ),
            AcpImageMutation(:final partIdSuffix, :final attachment) => _part(
              partId: "$messageId-$partIdSuffix",
              messageId: messageId,
              sessionId: sessionId,
              type: PluginMessagePartType.file,
              text: null,
              attachment: attachment,
            ),
          },
        ),
    ];
  }

  /// Maps a newly created ACP session before any prompt-derived events. The
  /// bridge uses this root event to hold those events until its durable
  /// backend-to-client session binding has committed.
  BridgeSseSessionCreated mapCreatedSession({required PluginSession session}) {
    final time = session.time;
    return BridgeSseSessionCreated(
      info: shared.Session(
        branchName: null,
        id: session.id,
        pluginId: pluginId,
        projectID: session.projectID,
        directory: session.directory,
        parentID: session.parentID,
        title: session.title,
        time: time == null
            ? null
            : shared.SessionTime(
                created: time.created,
                updated: time.updated,
                archived: time.archived,
              ),
        pullRequest: null,
        promptDefaults: null,
        lastUserActivityAt: null,
      ).toJson(),
    );
  }

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

    final messageTime = messageTimeForNotification(notification: notification);
    switch (update["sessionUpdate"] as String?) {
      case "agent_message_chunk":
        return _afterReasoning(
          sessionId: sessionId,
          events: _assistantContentChunk(sessionId: sessionId, update: update, time: messageTime),
        );
      case "agent_thought_chunk":
        return _textChunk(
          sessionId: sessionId,
          update: update,
          role: _ChunkRole.assistant,
          partSuffix: "reasoning",
          partType: PluginMessagePartType.reasoning,
          time: messageTime,
        );
      case "user_message_chunk":
        // A child session's first user message is the prompt its parent gave
        // it, which no client sent: it is the one source of the tile's prompt.
        if (childSessions.isChild(sessionId: sessionId)) {
          return _childPromptChunk(childSessionId: sessionId, update: update);
        }
        // This plugin emits the accepted prompt itself. A live user chunk is
        // the agent echoing that same prompt and would render it twice. Replay
        // is reconstructed separately by AcpReplayCollector.
        return const [];
      case "tool_call":
        return _afterReasoning(
          sessionId: sessionId,
          events: _toolCall(sessionId: sessionId, update: update, time: messageTime),
        );
      case "tool_call_update":
        return _afterReasoning(
          sessionId: sessionId,
          events: _toolCallUpdate(sessionId: sessionId, update: update, time: messageTime),
        );
      case "plan":
        return [BridgeSseTodoUpdated(sessionID: sessionId)];
      case "available_commands_update":
        // The advertised commands themselves are tracked by AcpCommandTracker
        // and served via getCommands. The catalog is process-wide, while the
        // options-change event retains the originating session for persistence.
        return [
          const BridgeSseCommandCatalogUpdated(),
          BridgeSseSessionOptionsChanged(sessionID: sessionId),
        ];
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
        // The agent's auto-generated title for the thread. An explicit null or
        // empty title clears it; absent leaves the cached title unchanged.
        if (update.containsKey("title")) {
          final rawTitle = update["title"];
          _sessionSnapshots.putIfAbsent(sessionId, _SessionSnapshot.new).title =
              rawTitle is String && rawTitle.isNotEmpty ? rawTitle : null;
        }
        // Session lists must receive timestamp-only metadata updates to retain
        // their activity ordering. With neither a title nor timestamp, this
        // update carries nothing the client can render.
        if (!update.containsKey("title") && eventUpdatedMs == null) return const [];
        return [
          BridgeSseSessionUpdated(
            info: _sessionUpdate(sessionId).toJson(),
            titleChanged: update.containsKey("title"),
          ),
        ];
    }

    // Dropped intentionally: current_mode_update (the mode is surfaced as the
    // session "variant", driven by the plugin, not a message event), and any
    // future standard variants the mobile UI has no renderer for.
    return const [];
  }

  List<BridgeSseEvent> _afterReasoning({
    required String sessionId,
    required List<BridgeSseEvent> events,
  }) {
    if (events.isEmpty) return events;
    return [
      ..._finalizeActiveTextParts(
        sessionId: sessionId,
        partType: PluginMessagePartType.reasoning,
        messageId: null,
      ),
      ...events,
    ];
  }

  List<BridgeSseEvent> _finalizeActiveTextParts({
    required String sessionId,
    required PluginMessagePartType partType,
    required String? messageId,
  }) {
    final accumulators = _textPartAccumulators[sessionId];
    if (accumulators == null) return const [];

    final events = <BridgeSseEvent>[];
    for (final accumulator in accumulators.values) {
      if (accumulator.type != partType ||
          !accumulator.isStreaming ||
          (messageId != null && accumulator.messageId != messageId)) {
        continue;
      }
      accumulator.isStreaming = false;
      events.add(
        BridgeSseMessagePartUpdated(
          part: _part(
            partId: accumulator.partId,
            messageId: accumulator.messageId,
            sessionId: sessionId,
            type: accumulator.type,
            text: accumulator.text.toString(),
            attachment: null,
          ),
        ),
      );
    }
    return events;
  }

  List<BridgeSseEvent> _finalizeCurrentIdlessAssistantText({required String sessionId}) {
    if (!_openIdlessAssistant.contains(sessionId)) return const [];
    return _finalizeActiveTextParts(
      sessionId: sessionId,
      partType: PluginMessagePartType.text,
      messageId: _currentIdlessAssistantMessageId(sessionId),
    );
  }

  /// Hook for non-`session/update` notifications (harness extensions such as
  /// Cursor's `cursor/update_todos`). Base implementation drops them.
  List<BridgeSseEvent> mapExtension(AcpNotification notification) => const [];

  /// Hook: whether a `tool_call` [update] is the harness's sub-agent spawn.
  /// A spawn call renders no tool card — its child's lifecycle notification
  /// opens the one tile — and its later `tool_call_update`s are dropped. Base
  /// backends spawn nothing this way; a harness mapper that recognizes its
  /// spawn tool overrides this.
  bool isSubagentSpawnToolCall({required Map<String, dynamic> update}) => false;

  /// Feeds a harness-reported sub-agent start under [sessionId] (the parent as
  /// the harness names it) to [childSessions]. The child's directory is the
  /// root's project.
  List<BridgeSseEvent> mapChildSpawned({required String sessionId, required AcpChildSpawn spawn}) {
    // Same boundary rule as [map]: an id-less session event is undeliverable.
    if (sessionId.isEmpty || spawn.childSessionId.isEmpty) return const [];
    return _childTileEvents(
      childSessions.spawn(
        sessionId: sessionId,
        spawn: spawn,
        directory: projectForSession(sessionId: childSessions.rootOf(sessionId: sessionId)),
      ),
    );
  }

  /// Records the model a harness reports for a spawned child, so the child's
  /// streamed messages are stamped with it instead of the process default.
  /// The provider is the root's: a child never switches providers.
  void setChildModel({required String childSessionId, required String? modelId}) =>
      _configurationTracker.setSessionOverride(
        sessionId: childSessionId,
        modelId: modelId,
        providerId: providerForSession(sessionId: childSessions.rootOf(sessionId: childSessionId)),
      );

  List<BridgeSseEvent> _childPromptChunk({required String childSessionId, required Map<String, dynamic> update}) {
    final text = _contentMapper.text(content: update["content"]);
    if (text == null || text.isEmpty) return const [];
    final result = childSessions.appendPrompt(childSessionId: childSessionId, delta: text);
    return result == null ? const [] : _childTileEvents(result);
  }

  /// A tile's first render needs the assistant envelope it hangs from.
  List<BridgeSseEvent> _childTileEvents(AcpChildTileResult result) => [
    if (result.opensMessage) _toolEnvelope(sessionId: result.rootSessionId, messageId: result.messageId, time: null),
    ...result.events,
  ];

  /// Feeds a harness-reported sub-agent finish to [childSessions].
  List<BridgeSseEvent> mapChildFinished({
    required String childSessionId,
    required PluginToolStatus status,
    required String? output,
    required String? error,
  }) => childSessions.finish(childSessionId: childSessionId, status: status, output: output, error: error);

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
  /// The returned notice classifies the text but cannot replace it; live and
  /// replay mapping retain [text] verbatim. Base backends never halt this way;
  /// harness subclasses that emit recognizable gate text (e.g. Cursor) override
  /// this. The history-replay collector also consults it so a reloaded session
  /// renders the notice the same way it did live.
  AcpHaltNotice? classifyHaltNotice({required String text}) => null;

  List<BridgeSseEvent> _assistantContentChunk({
    required String sessionId,
    required Map<String, dynamic> update,
    required PluginMessageTime? time,
  }) {
    final identity = _chunkIdentity(
      sessionId: sessionId,
      update: update,
      role: _ChunkRole.assistant,
    );
    final tracker = (_contentTrackers[sessionId] ??= {}).putIfAbsent(
      identity.messageId,
      AcpContentTracker.new,
    );
    final blocks = _contentMapper.mapScoped(
      content: update["content"],
      scope: tracker.mappingScope,
    );
    return _appendAssistantBlocks(
      sessionId: sessionId,
      identity: identity,
      tracker: tracker,
      blocks: blocks,
      time: time,
    );
  }

  /// Appends assistant image blocks normalized locally on the bridge (a harness
  /// extension that surfaces images outside standard ACP chunks) into the same
  /// ordered message state used by `agent_message_chunk`. The image-typed
  /// parameter also guarantees structurally that this path can never trip the
  /// text-only halt-notice classification in [_appendAssistantBlocks].
  List<BridgeSseEvent> appendAssistantImageBlocks({
    required String sessionId,
    required String? messageId,
    required Iterable<AcpMappedImageContentBlock> blocks,
  }) {
    final identity = _chunkIdentity(
      sessionId: sessionId,
      update: messageId == null ? const <String, dynamic>{} : <String, dynamic>{"messageId": messageId},
      role: _ChunkRole.assistant,
    );
    final tracker = (_contentTrackers[sessionId] ??= {}).putIfAbsent(
      identity.messageId,
      AcpContentTracker.new,
    );
    return _afterReasoning(
      sessionId: sessionId,
      events: _appendAssistantBlocks(
        sessionId: sessionId,
        identity: identity,
        tracker: tracker,
        blocks: blocks,
        time: null,
      ),
    );
  }

  List<BridgeSseEvent> _appendAssistantBlocks({
    required String sessionId,
    required ({String messageId, bool hasAcpMessageId}) identity,
    required AcpContentTracker tracker,
    required Iterable<AcpMappedContentBlock> blocks,
    required PluginMessageTime? time,
  }) {
    if (blocks.isEmpty) return const [];
    final hasTrackableContent = blocks.any(
      (block) => block is AcpMappedImageContentBlock || (block is AcpMappedTextContentBlock && block.text.isNotEmpty),
    );
    if (identity.hasAcpMessageId && hasTrackableContent) {
      _closeCurrentIdlessAssistantContent(sessionId: sessionId);
    }

    if (!identity.hasAcpMessageId &&
        tracker.snapshot.composition != AcpContentComposition.mixed &&
        blocks.every((block) => block is AcpMappedTextContentBlock)) {
      final text = blocks.whereType<AcpMappedTextContentBlock>().map((block) => block.text).join();
      if (text.isNotEmpty) {
        final halt = classifyHaltNotice(text: text);
        if (halt != null) return _haltNoticeEvents(sessionId: sessionId, notice: halt, message: text, time: time);
      }
    }

    final mutations = tracker.append(blocks: blocks);
    if (mutations.isEmpty) return const [];
    final events = <BridgeSseEvent>[];
    final started = _startedParts.putIfAbsent(sessionId, () => <String>{});
    if (started.add(identity.messageId)) {
      events.add(
        BridgeSseMessageUpdated(
          info: _messageFor(_ChunkRole.assistant, identity.messageId, sessionId, promptId: null, time: time).toJson(),
        ),
      );
    }
    for (final mutation in mutations) {
      final partId = "${identity.messageId}-${mutation.partIdSuffix}";
      switch (mutation) {
        case AcpTextDeltaMutation(:final delta):
          _recordTextDelta(
            sessionId: sessionId,
            messageId: identity.messageId,
            partId: partId,
            type: PluginMessagePartType.text,
            delta: delta,
          );
          if (started.add(partId)) {
            events.add(
              BridgeSseMessagePartUpdated(
                part: _part(
                  partId: partId,
                  messageId: identity.messageId,
                  sessionId: sessionId,
                  type: PluginMessagePartType.text,
                  text: "",
                  attachment: null,
                ),
              ),
            );
          }
          events.add(
            BridgeSseMessagePartDelta(
              sessionID: sessionId,
              messageID: identity.messageId,
              partID: partId,
              field: "text",
              delta: delta,
            ),
          );
        case AcpImageMutation(:final attachment):
          started.add(partId);
          events.add(
            BridgeSseMessagePartUpdated(
              part: _part(
                partId: partId,
                messageId: identity.messageId,
                sessionId: sessionId,
                type: PluginMessagePartType.file,
                text: null,
                attachment: attachment,
              ),
            ),
          );
      }
    }
    if (!identity.hasAcpMessageId) _openIdlessAssistant.add(sessionId);
    return events;
  }

  List<BridgeSseEvent> _textChunk({
    required String sessionId,
    required Map<String, dynamic> update,
    required _ChunkRole role,
    required String partSuffix,
    required PluginMessagePartType partType,
    required PluginMessageTime? time,
  }) {
    final text = _contentMapper.text(content: update["content"]);
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
      if (halt != null) return _haltNoticeEvents(sessionId: sessionId, notice: halt, message: text, time: time);
    }

    // ACP v1: chunks of one message share a `messageId`; a change starts a new
    // message. Group by it when present, so an agent emitting several same-role
    // messages in one turn doesn't collapse them into one sesori message. The
    // role stays in the id so a pathological cross-role id reuse can't merge a
    // user chunk into an assistant envelope. Absent (Cursor today) → the
    // synthesized per-turn id.
    final identity = _chunkIdentity(sessionId: sessionId, update: update, role: role);
    final messageId = identity.messageId;
    final partId = "$messageId-$partSuffix";

    final events = <BridgeSseEvent>[];
    final started = _startedParts.putIfAbsent(sessionId, () => <String>{});
    if (started.add(partId)) {
      if (started.add(messageId)) {
        events.add(
          BridgeSseMessageUpdated(info: _messageFor(role, messageId, sessionId, promptId: null, time: time).toJson()),
        );
      }
      events.add(
        BridgeSseMessagePartUpdated(
          part: _part(
            partId: partId,
            messageId: messageId,
            sessionId: sessionId,
            type: partType,
            text: "",
            attachment: null,
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
    _recordTextDelta(
      sessionId: sessionId,
      messageId: messageId,
      partId: partId,
      type: partType,
      delta: text,
    );
    if (role == _ChunkRole.assistant && !identity.hasAcpMessageId) {
      _openIdlessAssistant.add(sessionId);
    }
    return events;
  }

  void _recordTextDelta({
    required String sessionId,
    required String messageId,
    required String partId,
    required PluginMessagePartType type,
    required String delta,
  }) {
    final accumulator = (_textPartAccumulators[sessionId] ??= {}).putIfAbsent(
      partId,
      () => _TextPartAccumulator(
        partId: partId,
        messageId: messageId,
        type: type,
      ),
    );
    accumulator.text.write(delta);
    accumulator.isStreaming = true;
  }

  ({String messageId, bool hasAcpMessageId}) _chunkIdentity({
    required String sessionId,
    required Map<String, dynamic> update,
    required _ChunkRole role,
  }) {
    final acpMessageId = update["messageId"];
    final hasAcpMessageId = acpMessageId is String && acpMessageId.isNotEmpty;
    final fallbackSuffix = role == _ChunkRole.assistant ? "-a${_idlessAssistantSeq[sessionId] ?? 0}" : "";
    return (
      messageId: hasAcpMessageId
          ? "$sessionId-m$acpMessageId-${role.name}"
          : "${_fallbackTurnMessageId(sessionId)}-${role.name}$fallbackSuffix",
      hasAcpMessageId: hasAcpMessageId,
    );
  }

  /// Emits a backend halt [notice] (see [classifyHaltNotice]) as a single
  /// error message so the client renders it with its explicit error card
  /// instead of quiet assistant prose. The notice text rides in the error
  /// message itself, so no separate part is needed. Deduped per turn: a
  /// repeated identical chunk must not stack duplicate error cards.
  List<BridgeSseEvent> _haltNoticeEvents({
    required String sessionId,
    required AcpHaltNotice notice,
    required String message,
    required PluginMessageTime? time,
  }) {
    final messageId = "${_fallbackTurnMessageId(sessionId)}-halt";
    final started = _startedParts.putIfAbsent(sessionId, () => <String>{});
    if (!started.add(messageId)) return const [];
    // Any id-less assistant envelope opened earlier this turn is abandoned: the
    // halt notice is the turn's outcome and stands alone. Closing it bumps the
    // fallback sequence, so a later reordered id-less chunk recomputes a fresh
    // message id and opens a new envelope rather than appending a delta to the
    // abandoned one. (The dedupe return above runs first, so a repeated halt
    // chunk can't double-bump the sequence.)
    _closeCurrentIdlessAssistantContent(sessionId: sessionId);
    return [
      BridgeSseMessageUpdated(
        info: shared.Message.error(
          id: messageId,
          sessionID: sessionId,
          agent: pluginId,
          modelID: modelForSession(sessionId: sessionId),
          providerID: providerForSession(sessionId: sessionId),
          errorName: notice.errorName,
          errorMessage: message,
          time: time == null ? null : shared.MessageTime(created: time.created, completed: time.completed),
        ).toJson(),
      ),
    ];
  }

  List<BridgeSseEvent> _toolCall({
    required String sessionId,
    required Map<String, dynamic> update,
    required PluginMessageTime? time,
  }) {
    final toolCallId = update["toolCallId"] as String?;
    if (toolCallId == null || toolCallId.isEmpty) return const [];
    if (_spawnToolCalls[sessionId]?.contains(toolCallId) ?? false) return const [];
    final prior = _liveTools[sessionId]?[toolCallId];
    final boundaryEvents = prior == null
        ? _finalizeCurrentIdlessAssistantText(sessionId: sessionId)
        : const <BridgeSseEvent>[];
    if (prior == null) {
      _closeCurrentIdlessAssistantContent(sessionId: sessionId);
    }
    if (isSubagentSpawnToolCall(update: update)) {
      // A partial update that arrived first (no `_meta` to classify) may have
      // opened a provisional tool state; the full call retires it so later
      // updates are suppressed. The card it already rendered is accepted
      // residue of the reorder.
      _liveTools[sessionId]?.remove(toolCallId);
      (_spawnToolCalls[sessionId] ??= {}).add(toolCallId);
      return boundaryEvents;
    }
    final messageId = "$sessionId-tool-$toolCallId";
    final contentMutation = _contentMapper.toolContent(update: update);
    final contentTracker = prior?.contentTracker ?? AcpToolContentTracker();
    contentTracker.applyInitial(mutation: contentMutation);
    final hasKind = update["kind"] is String && (update["kind"] as String).isNotEmpty;
    final mappedStatus = _contentMapper.toolStatus(status: update["status"]);
    final useCallTool = prior == null || (!prior.hasExplicitKind && (hasKind || prior.tool == "tool"));
    final messageTime = _earliestMessageTime(prior?.time, time);
    final state = _LiveTool(
      // Fail-soft like the tool name and `_toolCallUpdate`'s title: a non-string
      // title (schema drift / malformed agent data) renders as null rather than
      // throwing and aborting the notification.
      tool: useCallTool ? _contentMapper.toolName(update: update) : prior.tool,
      title: prior?.title ?? (update["title"] is String ? update["title"] as String? : null),
      status: prior?.hasExplicitStatus ?? false ? prior!.status : mappedStatus ?? PluginToolStatus.pending,
      contentTracker: contentTracker,
      isFileMutation:
          (prior?.isFileMutation ?? false) ||
          _isFileMutation(
            update: update,
            contentMutation: contentMutation,
          ),
      diffEmitted: prior?.diffEmitted ?? false,
      hasExplicitKind: (prior?.hasExplicitKind ?? false) || hasKind,
      hasExplicitStatus: (prior?.hasExplicitStatus ?? false) || mappedStatus != null,
      time: messageTime,
    );
    (_liveTools[sessionId] ??= {})[toolCallId] = state;
    final events = <BridgeSseEvent>[
      ...boundaryEvents,
      if (prior == null || messageTime != prior.time)
        _toolEnvelope(sessionId: sessionId, messageId: messageId, time: messageTime),
      _toolPartEvent(sessionId: sessionId, messageId: messageId, state: state),
    ];
    _appendCompletedMutationDiff(
      events: events,
      sessionId: sessionId,
      state: state,
      mutationAvailable: _reportsDiff(mutation: contentMutation),
    );
    return events;
  }

  List<BridgeSseEvent> _toolCallUpdate({
    required String sessionId,
    required Map<String, dynamic> update,
    required PluginMessageTime? time,
  }) {
    final toolCallId = update["toolCallId"] as String?;
    if (toolCallId == null || toolCallId.isEmpty) return const [];
    if (_spawnToolCalls[sessionId]?.contains(toolCallId) ?? false) return const [];
    // A reordered spawn update (see the reorder note below) must not open a
    // tool card its `tool_call` would have suppressed.
    if (_liveTools[sessionId]?[toolCallId] == null && isSubagentSpawnToolCall(update: update)) {
      final boundaryEvents = _finalizeCurrentIdlessAssistantText(sessionId: sessionId);
      _closeCurrentIdlessAssistantContent(sessionId: sessionId);
      (_spawnToolCalls[sessionId] ??= {}).add(toolCallId);
      return boundaryEvents;
    }
    final messageId = "$sessionId-tool-$toolCallId";
    // A `tool_call_update` is a PARTIAL update: an agent may send only the
    // changed fields (e.g. `{status: completed}`). Merge onto the tool's prior
    // state so omitted name/title/content/status fields aren't reset to defaults,
    // which would blank an existing tool card. Mirrors the replay collector,
    // which already merges — keeping live and history renderings consistent.
    final prior = _liveTools[sessionId]?[toolCallId];
    final boundaryEvents = prior == null
        ? _finalizeCurrentIdlessAssistantText(sessionId: sessionId)
        : const <BridgeSseEvent>[];
    if (prior == null) {
      _closeCurrentIdlessAssistantContent(sessionId: sessionId);
    }
    // Only re-resolve the tool identifier when `kind` is explicitly present; a
    // title-only update must NOT overwrite the canonical id (e.g. "edit") with
    // the title text (`title` lives separately in PluginToolState.title). This
    // matches the replay collector, which preserves the original tool name.
    final hasKind = update["kind"] is String && (update["kind"] as String).isNotEmpty;
    final contentMutation = _contentMapper.toolContent(update: update);
    final contentTracker = prior?.contentTracker ?? AcpToolContentTracker();
    contentTracker.apply(mutation: contentMutation);
    final mappedStatus = _contentMapper.toolStatus(status: update["status"]);
    final messageTime = _earliestMessageTime(prior?.time, time);
    final state = _LiveTool(
      tool: hasKind
          ? _contentMapper.toolName(update: update)
          : (prior?.tool ?? _contentMapper.toolName(update: update)),
      title: update.containsKey("title") && update["title"] is String ? update["title"] as String? : prior?.title,
      status: mappedStatus ?? prior?.status ?? PluginToolStatus.pending,
      contentTracker: contentTracker,
      isFileMutation:
          (prior?.isFileMutation ?? false) ||
          _isFileMutation(
            update: update,
            contentMutation: contentMutation,
          ),
      diffEmitted: prior?.diffEmitted ?? false,
      hasExplicitKind: (prior?.hasExplicitKind ?? false) || hasKind,
      hasExplicitStatus: (prior?.hasExplicitStatus ?? false) || mappedStatus != null,
      time: messageTime,
    );
    final events = <BridgeSseEvent>[
      ...boundaryEvents,
      // ACP events can be reordered (reconnect / resume / replay), so a
      // `tool_call_update` may arrive before its `tool_call`. When it is
      // first-seen, synthesize the message envelope — like `_textChunk` does —
      // so the client can render the part instead of receiving an orphan it
      // drops.
      if (prior == null || messageTime != prior.time)
        _toolEnvelope(sessionId: sessionId, messageId: messageId, time: messageTime),
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
      mutationAvailable: _reportsDiff(mutation: contentMutation),
    );
    return events;
  }

  void _closeIdlessAssistantEnvelope(String sessionId) {
    if (!_openIdlessAssistant.remove(sessionId)) return;
    _idlessAssistantSeq[sessionId] = (_idlessAssistantSeq[sessionId] ?? 0) + 1;
  }

  void _closeCurrentIdlessAssistantContent({required String sessionId}) {
    final messageId = _currentIdlessAssistantMessageId(sessionId);
    final sessionTrackers = _contentTrackers[sessionId];
    sessionTrackers?.remove(messageId);
    if (sessionTrackers?.isEmpty ?? false) _contentTrackers.remove(sessionId);
    _closeIdlessAssistantEnvelope(sessionId);
  }

  String _currentIdlessAssistantMessageId(String sessionId) =>
      "${_fallbackTurnMessageId(sessionId)}-${_ChunkRole.assistant.name}-a${_idlessAssistantSeq[sessionId] ?? 0}";

  BridgeSseMessageUpdated _toolEnvelope({
    required String sessionId,
    required String messageId,
    required PluginMessageTime? time,
  }) {
    return BridgeSseMessageUpdated(
      info: shared.Message.assistant(
        id: messageId,
        sessionID: sessionId,
        agent: pluginId,
        modelID: modelForSession(sessionId: sessionId),
        providerID: providerForSession(sessionId: sessionId),
        sender: shared.MessageSender.agent,
        time: time == null ? null : shared.MessageTime(created: time.created, completed: time.completed),
      ).toJson(),
    );
  }

  PluginMessageTime? _earliestMessageTime(PluginMessageTime? prior, PluginMessageTime? next) {
    if (prior == null) return next;
    if (next == null || prior.created <= next.created) return prior;
    return next;
  }

  BridgeSseMessagePartUpdated _toolPartEvent({
    required String sessionId,
    required String messageId,
    required _LiveTool state,
  }) {
    final content = state.contentTracker.snapshot;
    return BridgeSseMessagePartUpdated(
      part: _toolPart(
        partId: "$messageId-call",
        messageId: messageId,
        sessionId: sessionId,
        tool: state.tool,
        state: PluginToolState(
          status: state.status,
          title: state.title,
          shellCommand: null,
          output: content.output,
          error: state.status == PluginToolStatus.error ? content.output : null,
          attachments: content.attachments,
        ),
      ),
    );
  }

  shared.Message _messageFor(
    _ChunkRole role,
    String messageId,
    String sessionId, {
    required String? promptId,
    required PluginMessageTime? time,
  }) {
    return switch (role) {
      _ChunkRole.user => shared.Message.user(
        id: messageId,
        sessionID: sessionId,
        agent: null,
        time: time == null ? null : shared.MessageTime(created: time.created, completed: time.completed),
        promptId: promptId,
      ),
      _ChunkRole.assistant => shared.Message.assistant(
        id: messageId,
        sessionID: sessionId,
        agent: pluginId,
        modelID: modelForSession(sessionId: sessionId),
        providerID: providerForSession(sessionId: sessionId),
        sender: shared.MessageSender.agent,
        time: time == null ? null : shared.MessageTime(created: time.created, completed: time.completed),
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
    final project = projectForSession(sessionId: id);
    final snapshot = _sessionSnapshots[id];
    final created = snapshot?.createdMs;
    final updated = snapshot?.updatedMs ?? created;
    return shared.Session(
      branchName: null,
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
      lastUserActivityAt: null,
    );
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
    required String? text,
    required PluginMessageAttachment? attachment,
  }) {
    return switch (type) {
      PluginMessagePartType.text => PluginMessagePart.text(
        id: partId,
        sessionID: sessionId,
        messageID: messageId,
        text: text!,
      ),
      PluginMessagePartType.reasoning => PluginMessagePart.reasoning(
        id: partId,
        sessionID: sessionId,
        messageID: messageId,
        text: text!,
      ),
      PluginMessagePartType.file => PluginMessagePart.file(
        id: partId,
        sessionID: sessionId,
        messageID: messageId,
        attachment: attachment!,
      ),
      _ => throw StateError("ACP content part cannot use $type"),
    };
  }

  PluginMessagePart _toolPart({
    required String partId,
    required String messageId,
    required String sessionId,
    required String tool,
    required PluginToolState state,
  }) {
    return PluginMessagePart.tool(
      id: partId,
      sessionID: sessionId,
      messageID: messageId,
      tool: tool,
      state: state,
    );
  }

  /// Whether a `tool_call`/`tool_call_update` payload reports a file mutation:
  /// a mutating `kind`, or a standard tool `content` entry of `type: "diff"`
  /// (a spec-compliant agent may report an edit only through the diff content
  /// shape, with a non-mutating or absent kind).
  bool _isFileMutation({
    required Map<String, dynamic> update,
    required AcpToolContentMutation contentMutation,
  }) {
    final kind = update["kind"];
    if (kind == "edit" || kind == "delete" || kind == "move") return true;
    return _reportsDiff(mutation: contentMutation);
  }

  bool _reportsDiff({required AcpToolContentMutation mutation}) {
    return switch (mutation) {
      AcpReplaceToolContentMutation(:final hasDiff) => hasDiff,
      AcpUpdateToolOutputMutation() || AcpUnchangedToolContentMutation() => false,
    };
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
    if (!_isTerminalToolStatus(state.status) && (!mutationAvailable || state.hasExplicitStatus)) {
      return;
    }
    state.diffEmitted = true;
    events.add(BridgeSseSessionDiff(sessionID: sessionId));
  }

  bool _isTerminalToolStatus(PluginToolStatus status) => status.isTerminal;

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }
}

enum _ChunkRole() {
  user,
  assistant,
}

/// Last-known metadata for one session, merged into the `session.updated`
/// payload a `session_info_update` emits.
class _SessionSnapshot() {
  String? title;
  int? createdMs;
  int? updatedMs;
}

class _TextPartAccumulator({
  required final String partId,
  required final String messageId,
  required final PluginMessagePartType type,
}) {
  final StringBuffer text = StringBuffer();
  bool isStreaming = false;
}

/// The last-rendered state of one live tool call, so a partial
/// `tool_call_update` merges onto it instead of replacing it.
class _LiveTool({
  required final String tool,
  required final String? title,
  required final PluginToolStatus status,
  required final AcpToolContentTracker contentTracker,
  required final bool isFileMutation,
  required var bool diffEmitted,
  required final bool hasExplicitKind,
  required final bool hasExplicitStatus,
  required final PluginMessageTime? time,
});
