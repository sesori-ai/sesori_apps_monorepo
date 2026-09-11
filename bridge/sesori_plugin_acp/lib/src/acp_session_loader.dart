import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "acp_event_mapper.dart" show AcpHaltNotice, AcpSessionUpdateNormalizer, AcpShellCommandResolver;
import "acp_protocol.dart" show AcpMethods;
import "acp_stdio_client.dart" show AcpNotification;
import "repositories/mappers/acp_content_mapper.dart";
import "repositories/trackers/acp_content_tracker.dart";
import "repositories/trackers/acp_tool_content_tracker.dart";

typedef AcpReplayUserMessageIdOverride = String? Function({required String acpMessageId});
typedef AcpReplayMessageTimeResolver = PluginMessageTime? Function({required Map<String, dynamic> params});
typedef AcpReplayToolPartReplacement = PluginMessagePart? Function({
  required String toolCallId,
  required PluginMessagePartTool toolPart,
});
typedef AcpReplayToolPartSuppression = bool Function({required Map<String, dynamic> update});
typedef AcpReplayCollectorFactory = AcpReplayCollector Function({
  required AcpReplayToolPartSuppression? toolPartSuppression,
});
typedef _AcpReplayAssistantSelection = ({String? modelId, String? providerId, String? variant});

/// Collects replay-process notifications into one immutable session history.
/// Harness implementations may consume extension notifications while the
/// default collector accepts only standard `session/update` frames.
abstract interface class AcpSessionReplayCollector() {
  void consumeNotification({required AcpNotification notification});

  List<PluginMessageWithParts> buildWithAssistantSelection({
    required String? modelId,
    required String? providerId,
    required String? variant,
  });
}

/// Accumulates the `session/update` notifications replayed by `session/load`
/// into ordered [PluginMessageWithParts] for `getSessionMessages`.
///
/// ACP replays a thread as a stream of chunk notifications in conversational
/// order; consecutive same-role chunks belong to one message, and a role
/// switch starts a new message.
class AcpReplayCollector({
  required final String sessionId,
  required final String agentId,
  required final String? initialUserMessageId,

  /// The live mapper's pure hook. Null retains standard ACP envelopes unchanged.
  required final AcpSessionUpdateNormalizer? sessionUpdateNormalizer,
  required final AcpShellCommandResolver? shellCommandResolver,

  /// Overrides a replayed user's ACP message id with backend authority.
  required final AcpReplayUserMessageIdOverride? messageIdOverride,

  /// Extracts an optional backend time from the complete replay envelope.
  required final AcpReplayMessageTimeResolver? messageTimeResolver,

  /// Classifies a fully-accumulated assistant message as a backend halt notice
  /// (see [AcpEventMapper.classifyHaltNotice]) so a reloaded session renders the
  /// notice as an error message exactly as it appeared live. Null on backends
  /// with no halt notices.
  required final AcpHaltNotice? Function({required String text})? haltClassifier,

  /// Replaces one materialized standard tool part with a harness-specific part.
  /// Null retains the generic ACP projection. This synchronous projection is
  /// replay-local; it must not read or mutate live lifecycle state.
  required final AcpReplayToolPartReplacement? toolPartReplacement,

  /// Suppresses a standard tool when typed wire metadata says a
  /// harness-specific replay entry owns its presentation. Kept separate from
  /// [toolPartReplacement] so DeepSeek's null-means-generic contract remains.
  required final AcpReplayToolPartSuppression? toolPartSuppression,
}) implements AcpSessionReplayCollector {
  static const AcpContentMapper _contentMapper = AcpContentMapper();

  final List<_Draft> _drafts = [];
  final List<_ReplayEntry> _entries = [];
  final Map<String, _InsertedAssistantMessage> _insertedById = {};
  final Map<String, int> _draftIdOccurrences = {};
  int _seq = 0;
  bool _hasUserDraft = false;
  _PendingAssistantContent? _pendingAssistantContent;

  @override
  void consumeNotification({required AcpNotification notification}) {
    if (notification.method == AcpMethods.sessionUpdate) consume(notification.params);
  }

  void consume(Map<String, dynamic> rawParams) {
    final params = sessionUpdateNormalizer?.call(params: rawParams) ?? rawParams;
    final update = _asMap(params["update"]);
    if (update == null) return;
    final rawSessionUpdate = update["sessionUpdate"];
    final sessionUpdate = rawSessionUpdate is String ? rawSessionUpdate : null;
    final time = messageTimeResolver?.call(params: params);
    if (sessionUpdate != "agent_message_chunk") {
      _pendingAssistantContent = null;
    }
    switch (sessionUpdate) {
      case "agent_message_chunk":
        _consumeAssistantContent(update: update, time: time);
      case "agent_thought_chunk":
        final t = _contentMapper.text(content: update["content"]);
        if (t != null) {
          final draft = _assistant(messageId: _chunkMessageId(update));
          _retainTime(draft: draft, time: time);
          draft.reasoning.write(t);
        }
      case "user_message_chunk":
        _consumeUserContent(update: update, time: time);
      case "tool_call":
        final id = update["toolCallId"] as String?;
        if (id == null) return;
        final contentMutation = _contentMapper.toolContent(update: update);
        final draft = _findTool(id);
        _retainTime(draft: draft == null ? _assistantForTool() : _draftForTool(id)!, time: time);
        final hasKind = update["kind"] is String && (update["kind"] as String).isNotEmpty;
        final mappedStatus = _contentMapper.toolStatus(status: update["status"]);
        final suppressed = toolPartSuppression?.call(update: update) ?? false;
        if (draft == null) {
          final contentTracker = AcpToolContentTracker()..applyInitial(mutation: contentMutation);
          _addTool(
            id: id,
            tool: _ToolDraft(
              tool: _contentMapper.toolName(update: update),
              title: _toolTitle(update),
              shellCommand: shellCommandResolver?.call(update: update),
              status: mappedStatus ?? PluginToolStatus.pending,
              contentTracker: contentTracker,
              hasExplicitKind: hasKind,
              hasExplicitStatus: mappedStatus != null,
              suppressed: suppressed,
            ),
          );
        } else {
          draft.suppressed = draft.suppressed || suppressed;
          if (!draft.hasExplicitKind && (hasKind || draft.tool == "tool")) {
            draft.tool = _contentMapper.toolName(update: update);
          }
          draft.title ??= _toolTitle(update);
          draft.shellCommand ??= shellCommandResolver?.call(update: update);
          if (!draft.hasExplicitStatus && mappedStatus != null) {
            draft.status = mappedStatus;
          }
          draft.contentTracker.applyInitial(mutation: contentMutation);
          draft.hasExplicitKind = draft.hasExplicitKind || hasKind;
          draft.hasExplicitStatus = draft.hasExplicitStatus || mappedStatus != null;
        }
      case "tool_call_update":
        final id = update["toolCallId"] as String?;
        if (id == null) return;
        final contentMutation = _contentMapper.toolContent(update: update);
        final draft = _findTool(id);
        _retainTime(draft: draft == null ? _assistantForTool() : _draftForTool(id)!, time: time);
        final hasKind = update["kind"] is String && (update["kind"] as String).isNotEmpty;
        final mappedStatus = _contentMapper.toolStatus(status: update["status"]);
        final suppressed = toolPartSuppression?.call(update: update) ?? false;
        if (draft == null) {
          // No prior `tool_call` was replayed for this id (loaded history can
          // carry only the update). Seed a tool draft from the update payload so
          // the card still renders, mirroring the live mapper which emits a tool
          // part unconditionally.
          final contentTracker = AcpToolContentTracker()..apply(mutation: contentMutation);
          _addTool(
            id: id,
            tool: _ToolDraft(
              tool: _contentMapper.toolName(update: update),
              title: _toolTitle(update),
              shellCommand: shellCommandResolver?.call(update: update),
              status: mappedStatus ?? PluginToolStatus.pending,
              contentTracker: contentTracker,
              hasExplicitKind: hasKind,
              hasExplicitStatus: mappedStatus != null,
              suppressed: suppressed,
            ),
          );
          return;
        }
        draft.suppressed = draft.suppressed || suppressed;
        // A `tool_call_update` is partial: only advance a field when the update
        // carries it, else a later output-only update would reset a
        // completed/failed replayed tool card back to pending (status) or drop a
        // separately-sent display title. Mirrors the live mapper's merge so
        // replayed history matches live rendering.
        if (mappedStatus != null) {
          draft.status = mappedStatus;
          draft.hasExplicitStatus = true;
        }
        if (hasKind) {
          draft.tool = _contentMapper.toolName(update: update);
          draft.hasExplicitKind = true;
        }
        if (update.containsKey("title")) draft.title = _toolTitle(update);
        draft.shellCommand = shellCommandResolver?.call(update: update) ?? draft.shellCommand;
        draft.contentTracker.apply(mutation: contentMutation);
    }
  }

  void _consumeUserContent({
    required Map<String, dynamic> update,
    required PluginMessageTime? time,
  }) {
    final draft = _user(messageId: _chunkMessageId(update));
    _retainTime(draft: draft, time: time);
    final blocks = _contentMapper.mapScoped(
      content: _stripUserImageUris(update["content"]),
      scope: draft.contentTracker.mappingScope,
    );
    for (final mutation in draft.contentTracker.append(blocks: blocks)) {
      draft.entries.add(_AssistantContentEntry(mutation: mutation));
    }
  }

  void _consumeAssistantContent({
    required Map<String, dynamic> update,
    required PluginMessageTime? time,
  }) {
    final messageId = _chunkMessageId(update);
    final existing = _matchingRole(role: "assistant", messageId: messageId);
    final AcpContentTracker tracker;
    if (existing != null) {
      tracker = existing.contentTracker;
      _pendingAssistantContent = null;
    } else {
      final pending = _pendingAssistantContent;
      if (pending != null && pending.messageId == messageId) {
        tracker = pending.tracker;
      } else {
        tracker = AcpContentTracker();
        _pendingAssistantContent = _PendingAssistantContent(
          messageId: messageId,
          tracker: tracker,
          time: time,
        );
      }
    }

    final blocks = _contentMapper.mapScoped(
      content: update["content"],
      scope: tracker.mappingScope,
    );
    final mutations = tracker.append(blocks: blocks);
    if (!_hasTrackableAssistantContent(blocks: blocks)) return;
    final draft =
        existing ??
        _newDraft(
          role: "assistant",
          messageId: messageId,
          overrideId: null,
          contentTracker: tracker,
        );
    final pendingTime = _pendingAssistantContent?.time;
    _pendingAssistantContent = null;
    _retainTime(draft: draft, time: pendingTime ?? time);
    for (final mutation in mutations) {
      draft.entries.add(_AssistantContentEntry(mutation: mutation));
    }
  }

  /// Inserts or updates one harness-owned assistant message at its first
  /// observed replay position. Updating preserves that position, so a later
  /// terminal lifecycle frame settles the original tile rather than appending.
  void upsertAssistantMessage({
    required String messageId,
    required List<PluginMessagePart> parts,
    required PluginMessageTime? time,
  }) {
    final existing = _insertedById[messageId];
    if (existing != null) {
      existing
        ..parts = List.unmodifiable(parts)
        ..time = time;
      return;
    }
    final inserted = _InsertedAssistantMessage(
      messageId: messageId,
      parts: List.unmodifiable(parts),
      time: time,
    );
    _insertedById[messageId] = inserted;
    _entries.add(inserted);
    _pendingAssistantContent = null;
  }

  /// Materializes replay without model-selection metadata.
  List<PluginMessageWithParts> build() => _build(
    selection: (modelId: null, providerId: null, variant: null),
    materializationToolPartReplacement: toolPartReplacement,
  );

  /// Materializes replay with one authoritative assistant selection tuple.
  ///
  /// Selection is supplied only after `session/load` settles, so callers never
  /// mutate partially-known collector state while notifications are arriving.
  @override
  List<PluginMessageWithParts> buildWithAssistantSelection({
    required String? modelId,
    required String? providerId,
    required String? variant,
  }) => _build(
    selection: (modelId: modelId, providerId: providerId, variant: variant),
    materializationToolPartReplacement: toolPartReplacement,
  );

  /// Materializes replay through the same ordered path with a caller-owned
  /// replay-local tool replacement. Constructor configuration remains intact
  /// for every other materialization method.
  List<PluginMessageWithParts> buildWithToolPartReplacement({
    required String? modelId,
    required String? providerId,
    required String? variant,
    required AcpReplayToolPartReplacement toolPartReplacement,
  }) => _build(
    selection: (modelId: modelId, providerId: providerId, variant: variant),
    materializationToolPartReplacement: toolPartReplacement,
  );

  List<PluginMessageWithParts> _build({
    required _AcpReplayAssistantSelection selection,
    required AcpReplayToolPartReplacement? materializationToolPartReplacement,
  }) {
    final messages = <PluginMessageWithParts>[];
    for (final entry in _entries) {
      switch (entry) {
        case _Draft():
          final message = _buildMessage(
            draft: entry,
            selection: selection,
            materializationToolPartReplacement: materializationToolPartReplacement,
          );
          if (message != null) messages.add(message);
        case _InsertedAssistantMessage():
          messages.add(
            PluginMessageWithParts(
              info: PluginMessage.assistant(
                id: entry.messageId,
                sessionID: sessionId,
                agent: agentId,
                modelID: selection.modelId,
                providerID: selection.providerId,
                variant: selection.variant,
                sender: PluginMessageSender.agent,
                time: entry.time,
              ),
              parts: entry.parts,
            ),
          );
      }
    }
    return messages;
  }

  PluginMessageWithParts? _buildMessage({
    required _Draft draft,
    required _AcpReplayAssistantSelection selection,
    required AcpReplayToolPartReplacement? materializationToolPartReplacement,
  }) {
    // A recognized halt notice (e.g. Cursor's account/plan gate, streamed as a
    // lone assistant message) is surfaced as an error message so a reloaded
    // session matches the live rendering. Only a pure-text terminal notice
    // qualifies — no reasoning, no tools — matching the shape the backend emits.
    final assistantText = _assistantText(draft: draft);
    if (draft.role == "assistant" &&
        draft.acpMessageId == null &&
        draft.reasoning.isEmpty &&
        draft.tools.isEmpty &&
        !_hasAssistantImageCandidate(draft: draft) &&
        draft.contentTracker.snapshot.composition == AcpContentComposition.textOnly &&
        assistantText.isNotEmpty) {
      final halt = haltClassifier?.call(text: assistantText);
      if (halt != null) {
        return PluginMessageWithParts(
          info: PluginMessage.error(
            id: draft.id,
            sessionID: sessionId,
            agent: agentId,
            modelID: selection.modelId,
            providerID: selection.providerId,
            variant: selection.variant,
            errorName: halt.errorName,
            errorMessage: assistantText,
            time: draft.time,
          ),
          parts: const [],
        );
      }
    }
    final parts = <PluginMessagePart>[];
    if (draft.reasoning.isNotEmpty) {
      parts.add(_textPart(draft, "reasoning", PluginMessagePartType.reasoning, draft.reasoning.toString()));
    }
    if (draft.text.isNotEmpty) {
      parts.add(_textPart(draft, "text", PluginMessagePartType.text, draft.text.toString()));
    }
    parts.addAll(
      _chronologicalAssistantParts(
        draft: draft,
        materializationToolPartReplacement: materializationToolPartReplacement,
      ),
    );
    if (parts.isEmpty && draft.tools.values.any((tool) => tool.suppressed)) return null;
    return PluginMessageWithParts(
      info: _message(draft: draft, selection: selection),
      parts: parts,
    );
  }

  bool _hasTrackableAssistantContent({
    required List<AcpMappedContentBlock> blocks,
  }) {
    return blocks.any(
      (block) => block is AcpMappedImageContentBlock || (block is AcpMappedTextContentBlock && block.text.isNotEmpty),
    );
  }

  String _assistantText({required _Draft draft}) {
    final buffer = StringBuffer();
    for (final entry in draft.entries) {
      if (entry case _AssistantContentEntry(mutation: AcpTextDeltaMutation(:final delta))) {
        buffer.write(delta);
      }
    }
    return buffer.toString();
  }

  bool _hasAssistantImageCandidate({required _Draft draft}) => draft.contentTracker.snapshot.imageCandidateCount > 0;

  List<PluginMessagePart> _chronologicalAssistantParts({
    required _Draft draft,
    required AcpReplayToolPartReplacement? materializationToolPartReplacement,
  }) {
    final parts = <PluginMessagePart>[];
    String? textPartIdSuffix;
    StringBuffer? textBuffer;

    void flushText() {
      final suffix = textPartIdSuffix;
      final buffer = textBuffer;
      if (suffix != null && buffer != null) {
        parts.add(
          _textPart(
            draft,
            suffix,
            PluginMessagePartType.text,
            buffer.toString(),
          ),
        );
      }
      textPartIdSuffix = null;
      textBuffer = null;
    }

    for (final entry in draft.entries) {
      switch (entry) {
        case _AssistantContentEntry(:final mutation):
          switch (mutation) {
            case AcpTextDeltaMutation(:final partIdSuffix, :final delta):
              if (textPartIdSuffix != partIdSuffix) {
                flushText();
                textPartIdSuffix = partIdSuffix;
                textBuffer = StringBuffer();
              }
              textBuffer!.write(delta);
            case AcpImageMutation(:final partIdSuffix, :final attachment):
              flushText();
              parts.add(
                _attachmentPart(
                  draft: draft,
                  suffix: partIdSuffix,
                  attachment: attachment,
                ),
              );
          }
        case _AssistantToolEntry(:final toolId, :final tool):
          flushText();
          final part = _toolPart(
            draft: draft,
            toolId: toolId,
            tool: tool,
            materializationToolPartReplacement: materializationToolPartReplacement,
          );
          if (part != null) parts.add(part);
      }
    }
    flushText();
    return parts;
  }

  PluginMessage _message({required _Draft draft, required _AcpReplayAssistantSelection selection}) {
    if (draft.role == "user") {
      return PluginMessage.user(
        id: draft.id,
        sessionID: sessionId,
        agent: null,
        time: draft.time,
        promptId: null,
      );
    }
    return PluginMessage.assistant(
      id: draft.id,
      sessionID: sessionId,
      agent: agentId,
      modelID: selection.modelId,
      providerID: selection.providerId,
      variant: selection.variant,
      sender: PluginMessageSender.agent,
      time: draft.time,
    );
  }

  PluginMessagePart _textPart(
    _Draft draft,
    String suffix,
    PluginMessagePartType type,
    String text,
  ) {
    return switch (type) {
      PluginMessagePartType.text => PluginMessagePart.text(
        id: "${draft.id}-$suffix",
        sessionID: sessionId,
        messageID: draft.id,
        text: text,
      ),
      PluginMessagePartType.reasoning => PluginMessagePart.reasoning(
        id: "${draft.id}-$suffix",
        sessionID: sessionId,
        messageID: draft.id,
        text: text,
      ),
      _ => throw StateError("ACP text part cannot use $type"),
    };
  }

  PluginMessagePart _attachmentPart({
    required _Draft draft,
    required String suffix,
    required PluginMessageAttachment attachment,
  }) {
    return PluginMessagePart.file(
      id: "${draft.id}-$suffix",
      sessionID: sessionId,
      messageID: draft.id,
      attachment: attachment,
    );
  }

  PluginMessagePart? _toolPart({
    required _Draft draft,
    required String toolId,
    required _ToolDraft tool,
    required AcpReplayToolPartReplacement? materializationToolPartReplacement,
  }) {
    if (tool.suppressed) return null;
    final content = tool.contentTracker.snapshot;
    final toolPart = PluginMessagePartTool(
      id: "${draft.id}-tool-$toolId",
      sessionID: sessionId,
      messageID: draft.id,
      tool: tool.tool,
      state: PluginToolState(
        status: tool.status,
        title: tool.title,
        shellCommand: tool.shellCommand,
        output: content.output,
        error: tool.status == PluginToolStatus.error ? content.output : null,
        attachments: content.attachments,
      ),
    );
    return materializationToolPartReplacement?.call(toolCallId: toolId, toolPart: toolPart) ?? toolPart;
  }

  void _retainTime({required _Draft draft, required PluginMessageTime? time}) {
    if (time != null && (draft.time == null || time.created < draft.time!.created)) {
      draft.time = time;
    }
  }

  _Draft _assistant({String? messageId}) => _ensureRole("assistant", messageId: messageId, overrideId: null);
  _Draft _user({String? messageId}) => _ensureRole(
    "user",
    messageId: messageId,
    overrideId: messageId == null ? null : messageIdOverride?.call(acpMessageId: messageId),
  );

  // Tool calls carry no messageId (they are not ContentChunks) and attach to
  // the current assistant message even when its content chunks are stamped.
  _Draft _assistantForTool() {
    if (_entries.isNotEmpty) {
      final entry = _entries.last;
      if (entry is _Draft && entry.role == "assistant") {
        if (entry.acpMessageId != null || (entry.text.isEmpty && entry.reasoning.isEmpty && entry.entries.isEmpty)) {
          return entry;
        }
      }
    }
    return _newDraft(
      role: "assistant",
      messageId: null,
      overrideId: null,
      contentTracker: null,
    );
  }

  void _addTool({required String id, required _ToolDraft tool}) {
    final draft = _assistantForTool();
    draft.tools[id] = tool;
    draft.entries.add(_AssistantToolEntry(toolId: id, tool: tool));
    draft.contentTracker.closeTextPart();
  }

  /// The draft the next chunk belongs to. ACP v1: chunks of one message share
  /// a `messageId`, and a change starts a new message — so the last draft is
  /// reused only when both the role AND the message id match. An id-less
  /// content chunk continues only an id-less draft; tool attachments use
  /// [_assistantForTool] because ACP does not stamp them. Comparison is against
  /// the last draft only, matching the spec's sequential semantics.
  _Draft _ensureRole(String role, {required String? messageId, required String? overrideId}) {
    return _matchingRole(role: role, messageId: messageId) ??
        _newDraft(
          role: role,
          messageId: messageId,
          overrideId: overrideId,
          contentTracker: null,
        );
  }

  _Draft? _matchingRole({required String role, required String? messageId}) {
    if (_entries.isEmpty) return null;
    final entry = _entries.last;
    if (entry is! _Draft || entry.role != role) return null;
    if (entry.acpMessageId != messageId || (messageId == null && entry.tools.isNotEmpty)) {
      return null;
    }
    return entry;
  }

  _Draft _newDraft({
    required String role,
    required String? messageId,
    required String? overrideId,
    required AcpContentTracker? contentTracker,
  }) {
    final isFirstUser = role == "user" && !_hasUserDraft;
    if (role == "user") _hasUserDraft = true;
    final defaultId =
        overrideId ??
        (messageId != null && messageId.isNotEmpty ? "$sessionId-m$messageId-$role" : "$sessionId-h${_seq++}-$role");
    final identity = isFirstUser && initialUserMessageId != null ? initialUserMessageId! : defaultId;
    final occurrence = (_draftIdOccurrences[identity] ?? 0) + 1;
    _draftIdOccurrences[identity] = occurrence;
    final draft = _Draft(
      role: role,
      id: occurrence == 1 ? identity : "$identity-segment-$occurrence",
      acpMessageId: messageId,
      contentTracker: contentTracker ?? AcpContentTracker(),
    );
    _drafts.add(draft);
    _entries.add(draft);
    return draft;
  }

  /// The chunk's ACP `messageId`, when present and well-formed.
  static String? _chunkMessageId(Map<String, dynamic> update) {
    final id = update["messageId"];
    return id is String && id.isNotEmpty ? id : null;
  }

  _ToolDraft? _findTool(String toolId) => _draftForTool(toolId)?.tools[toolId];

  _Draft? _draftForTool(String toolId) {
    for (final draft in _drafts.reversed) {
      if (draft.tools.containsKey(toolId)) return draft;
    }
    return null;
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  Object? _stripUserImageUris(Object? content) {
    if (content is List) {
      return content.map(_stripUserImageUris).toList(growable: false);
    }
    final block = _asMap(content);
    if (block == null || block["type"] != "image") return content;
    return Map<String, dynamic>.of(block)..remove("uri");
  }

  /// Fail-soft tool title: a non-string value (schema drift / malformed agent
  /// data) renders as null rather than throwing mid-replay, which would fail
  /// the whole `/session/messages` history load.
  static String? _toolTitle(Map<String, dynamic> update) =>
      update["title"] is String ? update["title"] as String? : null;
}

sealed class _ReplayEntry();

final class _InsertedAssistantMessage({
  required final String messageId,
  required var List<PluginMessagePart> parts,
  required var PluginMessageTime? time,
}) extends _ReplayEntry;

class _Draft({
  required final String role,
  required final String id,

  /// The ACP `messageId` this draft groups, when the agent stamped one.
  required var String? acpMessageId,
  required final AcpContentTracker contentTracker,
}) extends _ReplayEntry {
  final StringBuffer text = StringBuffer();
  final StringBuffer reasoning = StringBuffer();
  final List<_AssistantDraftEntry> entries = [];
  final Map<String, _ToolDraft> tools = {};
  PluginMessageTime? time;
}

sealed class const _AssistantDraftEntry();

final class const _AssistantContentEntry({required final AcpContentMutation mutation}) extends _AssistantDraftEntry;

final class const _AssistantToolEntry({required final String toolId, required final _ToolDraft tool})
    extends _AssistantDraftEntry;

final class const _PendingAssistantContent({
  required final String? messageId,
  required final AcpContentTracker tracker,
  required final PluginMessageTime? time,
});

class _ToolDraft({
  required var String? shellCommand,
  required var String tool,
  required var String? title,
  required var PluginToolStatus status,
  required final AcpToolContentTracker contentTracker,
  required var bool hasExplicitKind,
  required var bool hasExplicitStatus,
  required var bool suppressed,
}) {
  // Reassigned as later tool_call_update notifications arrive during replay.
}
