import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart"
    show
        decodedBase64Length,
        isTranscriptImageBase64LengthWithinSizeLimit,
        maxTranscriptImageBytes,
        maxTranscriptImageCandidates,
        maxTranscriptImageCollectionBytes;

import "../../api/models/claude_content_block_dto.dart";
import "../../models/claude_message_origin_kind.dart";
import "../../models/claude_task_notification.dart";
import "claude_shell_command_mapper.dart";
import "claude_task_status_mapping.dart";
import "claude_tool_kind_mapper.dart";
import "claude_tool_title_mapper.dart";

sealed class const ClaudeMappedContentBlock();

final class const ClaudeMappedTextContentBlock({required final String text}) extends ClaudeMappedContentBlock;

/// A text block that is a complete `<task-notification>` envelope.
///
/// Consumers finalize the named task and hide the block only when its tool-use
/// id is a task they know; otherwise it renders as an Automation step. A prompt
/// that merely discusses the protocol is not a whole envelope, so it can
/// neither vanish nor finalize a subtask.
final class const ClaudeMappedTaskNotificationContentBlock({
  required final ClaudeTaskNotification notification,
  required final String text,
}) extends ClaudeMappedContentBlock;

final class const ClaudeMappedThinkingContentBlock({required final String thinking}) extends ClaudeMappedContentBlock;

final class const ClaudeMappedToolUseContentBlock({
  required final String id,
  required final String name,
  required final Object? input,
}) extends ClaudeMappedContentBlock;

final class const ClaudeMappedToolResultContentBlock({
  required final String toolUseId,
  required final String? output,
  required final bool isError,
  required final List<PluginMessageAttachment> attachments,
}) extends ClaudeMappedContentBlock;

final class const ClaudeMappedImageContentBlock({required final PluginMessageAttachment attachment})
    extends ClaudeMappedContentBlock;

final class const ClaudeMappedUnsupportedContentBlock() extends ClaudeMappedContentBlock;

final class const ClaudeMappedUnknownContentBlock() extends ClaudeMappedContentBlock;

/// Maps Claude's standard Anthropic content blocks into backend-neutral parts.
///
/// This class is stateless. Tool-use correlation and lifecycle remain Step 7's
/// responsibility; the mapped variants retain the identities and input needed
/// there.
final class const ClaudeContentMapper() {
  static const int _maxMimeCharacters = 255;
  static const Set<String> _supportedImageMimes = {
    "image/gif",
    "image/jpeg",
    "image/png",
    "image/webp",
  };

  List<ClaudeMappedContentBlock> map({required Object? content}) {
    final state = _ClaudeContentMappingState();
    return _mapValue(content: content, state: state).toList(growable: false);
  }

  static const List<String> _internalCommandMarkers = [
    "<local-command-stdout>",
    "<local-command-caveat>",
    "<command-name>",
    "<command-message>",
  ];

  /// Whether [blocks] carry the CLI's internal slash-command envelope or local
  /// command output, which is never rendered as a user message.
  ///
  /// The envelope always leads with its tag, so only a block that *starts*
  /// with a marker is internal. A prompt that merely mentions a marker mid-text
  /// stays visible — with replay as the only echo source, a substring match
  /// would silently hide that prompt everywhere.
  bool containsInternalCommandOutput({required List<ClaudeMappedContentBlock> blocks}) => blocks.any(
    (block) =>
        block is ClaudeMappedTextContentBlock &&
        _internalCommandMarkers.any((marker) => block.text.trimLeft().startsWith(marker)),
  );

  /// Strips the bridge-owned worktree context envelope from user [content], so
  /// both the live replay echo and the persisted transcript render only the
  /// user-authored text.
  Object? visibleUserContent({required Object? content}) {
    if (content is String) {
      final text = _stripBridgeContext(content);
      return text == null || text.isEmpty
          ? const <Object?>[]
          : [
              {"type": "text", "text": text},
            ];
    }
    if (content is! List) return content;
    final visible = <Object?>[];
    for (final block in content) {
      if (block is Map && block["type"] == "text" && block["text"] is String) {
        final text = _stripBridgeContext(block["text"]! as String);
        if (text != null && text.isNotEmpty) visible.add({...block.cast<String, Object?>(), "text": text});
      } else {
        visible.add(block);
      }
    }
    return visible;
  }

  String? _stripBridgeContext(String text) {
    const marker = "[SYSTEM CONTEXT \u2014 IMPORTANT]";
    final markerIndex = text.indexOf(marker);
    if (markerIndex < 0) return text;
    final envelopeEnd = text.indexOf("\n---", markerIndex);
    if (envelopeEnd < 0) return text;
    final trailing = text.substring(envelopeEnd + "\n---".length).trim();
    final prefix = text.substring(0, markerIndex).trim();
    if (prefix.isEmpty) return trailing.isEmpty ? null : trailing;
    if (!prefix.startsWith("/")) return text;
    return trailing.isEmpty ? prefix : "$prefix $trailing";
  }

  /// Projects visible user-role content consistently for live and stored rows.
  /// Explicit peer provenance identifies automation regardless of prompt hints;
  /// only ordinary stdin replays can replace a queued human prompt.
  PluginMessageWithParts? userMessage({
    required String sessionId,
    required String messageId,
    required PluginMessageTime? time,
    required Object? content,
    required ClaudeMessageOriginKind originKind,
    required String? promptId,
  }) {
    final isPeer = originKind == ClaudeMessageOriginKind.peer;
    final parts = mapParts(
      content: isPeer ? content : visibleUserContent(content: content),
      sessionId: sessionId,
      messageId: messageId,
    );
    if (!_hasVisibleContent(parts: parts)) return null;
    return PluginMessageWithParts(
      info: isPeer
          ? _automationInfo(sessionId: sessionId, messageId: messageId, time: time)
          : PluginMessage.user(
              id: messageId,
              sessionID: sessionId,
              agent: null,
              time: time,
              promptId: promptId,
            ),
      parts: parts,
    );
  }

  /// Whether a user turn is the CLI's delivery of a background-task outcome:
  /// its provenance says so or, on CLIs that record no origin, one of its
  /// [blocks] is a whole `<task-notification>` envelope.
  bool isTaskNotification({
    required List<ClaudeMappedContentBlock> blocks,
    required ClaudeMessageOriginKind originKind,
  }) =>
      originKind == ClaudeMessageOriginKind.taskNotification ||
      blocks.any(
        (block) => switch (block) {
          ClaudeMappedTaskNotificationContentBlock() => true,
          ClaudeMappedTextContentBlock(:final text) => ClaudeTaskNotification.isEnvelope(text),
          _ => false,
        },
      );

  /// The Automation row for a task-notification turn, never a user bubble.
  ///
  /// [notifications] are the parsed envelopes no known task absorbed; each
  /// becomes one finished step labelled by its summary. With none, the turn's
  /// raw text is shown as-is. Null when nothing is visible.
  PluginMessageWithParts? taskNotificationMessage({
    required String sessionId,
    required String messageId,
    required PluginMessageTime? time,
    required Object? content,
    required List<ClaudeTaskNotification> notifications,
  }) {
    final parts = notifications.isEmpty
        ? mapParts(content: content, sessionId: sessionId, messageId: messageId)
        : [
            for (final (index, notification) in notifications.indexed)
              _taskNotificationPart(
                notification: notification,
                id: "$messageId-task-$index",
                sessionId: sessionId,
                messageId: messageId,
              ),
          ];
    if (!_hasVisibleContent(parts: parts)) return null;
    return PluginMessageWithParts(
      info: _automationInfo(sessionId: sessionId, messageId: messageId, time: time),
      parts: parts,
    );
  }

  PluginMessagePart _taskNotificationPart({
    required ClaudeTaskNotification notification,
    required String id,
    required String sessionId,
    required String messageId,
  }) {
    final status = notification.status.toPluginToolStatus();
    return PluginMessagePart.tool(
      id: id,
      sessionID: sessionId,
      messageID: messageId,
      tool: notification.summary,
      kind: PluginToolKind.other,
      state: PluginToolState(
        status: status,
        title: null,
        shellCommand: null,
        output: _boundedToolOutput(notification.result ?? ""),
        error: status == PluginToolStatus.error ? notification.summary : null,
        attachments: const [],
      ),
    );
  }

  bool _hasVisibleContent({required List<PluginMessagePart> parts}) =>
      parts.any((part) => part.type.isVisible && (part is! PluginMessagePartText || part.text.isNotEmpty));

  PluginMessage _automationInfo({
    required String sessionId,
    required String messageId,
    required PluginMessageTime? time,
  }) => PluginMessage.assistant(
    id: messageId,
    sessionID: sessionId,
    agent: null,
    modelID: null,
    providerID: null,
    variant: null,
    sender: PluginMessageSender.system,
    time: time,
  );

  /// The compaction row for the continuation summary [content] the CLI
  /// injects as a user turn right after compacting.
  PluginMessageWithParts compactionMessage({
    required String sessionId,
    required String messageId,
    required PluginMessageTime? time,
    required Object? content,
  }) {
    final summary = [
      for (final block in map(content: content))
        if (block case ClaudeMappedTextContentBlock(:final text)) text,
    ].join("\n\n").trim();
    return PluginMessageWithParts(
      info: PluginMessage.assistant(
        id: messageId,
        sessionID: sessionId,
        agent: "claude",
        modelID: null,
        providerID: "anthropic",
        variant: null,
        sender: PluginMessageSender.agent,
        time: time,
      ),
      parts: [
        PluginMessagePart.compaction(
          id: "$messageId-compaction",
          sessionID: sessionId,
          messageID: messageId,
          summary: summary.isEmpty ? null : summary,
        ),
      ],
    );
  }

  List<PluginMessagePart> mapParts({
    required Object? content,
    required String sessionId,
    required String messageId,
  }) {
    final blocks = map(content: content);
    return [
      for (var index = 0; index < blocks.length; index++)
        mapPart(block: blocks[index], index: index, sessionId: sessionId, messageId: messageId),
    ];
  }

  Iterable<ClaudeMappedContentBlock> _mapValue({
    required Object? content,
    required _ClaudeContentMappingState state,
  }) sync* {
    if (content == null) return;
    if (content is String) {
      yield _textBlock(content);
      return;
    }
    if (content is List) {
      for (final entry in content) {
        yield* _mapValue(content: entry, state: state);
      }
      return;
    }
    if (content is! Map) {
      yield const ClaudeMappedUnknownContentBlock();
      return;
    }

    final ClaudeContentBlockDto dto;
    try {
      dto = ClaudeContentBlockDto.fromJson(content.cast<String, dynamic>());
    } on Object catch (error, stackTrace) {
      Log.w(
        "[claude] content block decode failed "
        "(fields: ${content.length}, discriminator type: ${content["type"].runtimeType})",
        error.runtimeType,
        stackTrace,
      );
      yield const ClaudeMappedUnknownContentBlock();
      return;
    }

    switch (dto) {
      case ClaudeTextContentBlockDto(:final text):
        yield text == null ? const ClaudeMappedUnknownContentBlock() : _textBlock(text);
      case ClaudeThinkingContentBlockDto(:final thinking):
        yield thinking == null
            ? const ClaudeMappedUnknownContentBlock()
            : ClaudeMappedThinkingContentBlock(thinking: thinking);
      case ClaudeToolUseContentBlockDto(:final id, :final name, :final input):
        yield id == null || id.isEmpty || name == null || name.isEmpty
            ? const ClaudeMappedUnknownContentBlock()
            : ClaudeMappedToolUseContentBlock(id: id, name: name, input: input);
      case ClaudeToolResultContentBlockDto(:final toolUseId, :final content, :final isError):
        if (toolUseId == null || toolUseId.isEmpty) {
          yield const ClaudeMappedUnknownContentBlock();
        } else {
          yield _mapToolResult(toolUseId: toolUseId, content: content, isError: isError ?? false, state: state);
        }
      case ClaudeImageContentBlockDto(:final source):
        yield state.takeCandidate()
            ? ClaudeMappedImageContentBlock(
                attachment: _mapImage(source: source, state: state),
              )
            : const ClaudeMappedUnsupportedContentBlock();
      case ClaudeRedactedThinkingContentBlockDto():
        yield const ClaudeMappedUnsupportedContentBlock();
      case ClaudeUnknownContentBlockDto():
        yield const ClaudeMappedUnknownContentBlock();
    }
  }

  ClaudeMappedContentBlock _textBlock(String text) {
    final notification = ClaudeTaskNotification.tryParse(text);
    return notification == null
        ? ClaudeMappedTextContentBlock(text: text)
        : ClaudeMappedTaskNotificationContentBlock(notification: notification, text: text);
  }

  ClaudeMappedToolResultContentBlock _mapToolResult({
    required String toolUseId,
    required Object? content,
    required bool isError,
    required _ClaudeContentMappingState state,
  }) {
    final outputBuffer = StringBuffer();
    final attachments = <PluginMessageAttachment>[];
    for (final block in _mapValue(content: content, state: state)) {
      switch (block) {
        case ClaudeMappedTextContentBlock(text: final value) ||
            ClaudeMappedTaskNotificationContentBlock(text: final value):
          outputBuffer.write(value);
        case ClaudeMappedImageContentBlock(:final attachment):
          attachments.add(attachment);
        case ClaudeMappedThinkingContentBlock() ||
            ClaudeMappedToolUseContentBlock() ||
            ClaudeMappedToolResultContentBlock() ||
            ClaudeMappedUnsupportedContentBlock() ||
            ClaudeMappedUnknownContentBlock():
          continue;
      }
    }
    final output = _boundedToolOutput(outputBuffer.toString());
    return ClaudeMappedToolResultContentBlock(
      toolUseId: toolUseId,
      output: output,
      isError: isError,
      attachments: List.unmodifiable(attachments),
    );
  }

  PluginMessageAttachment _mapImage({
    required ClaudeImageSourceDto? source,
    required _ClaudeContentMappingState state,
  }) {
    final mime = _normalizedMime(source?.mediaType);
    final data = source?.data;
    if (source?.type != "base64" || !_supportedImageMimes.contains(mime) || data == null || data.isEmpty) {
      return PluginMessageAttachment.metadata(mime: mime, filename: null);
    }
    if (!isTranscriptImageBase64LengthWithinSizeLimit(base64Length: data.length)) {
      return PluginMessageAttachment.metadata(mime: mime, filename: null);
    }

    final String normalized;
    try {
      normalized = base64.normalize(data);
    } on FormatException {
      return PluginMessageAttachment.metadata(mime: mime, filename: null);
    }
    if (!isTranscriptImageBase64LengthWithinSizeLimit(base64Length: normalized.length)) {
      return PluginMessageAttachment.metadata(mime: mime, filename: null);
    }
    final decodedBytes = decodedBase64Length(base64Data: normalized);
    if (decodedBytes > maxTranscriptImageBytes) {
      return PluginMessageAttachment.metadata(mime: mime, filename: null);
    }
    if (decodedBytes > state.remainingImageBytes) {
      return PluginMessageAttachment.metadata(mime: mime, filename: null);
    }
    state.remainingImageBytes -= decodedBytes;
    return PluginMessageAttachment.inlineImage(mime: mime, base64: normalized, filename: null);
  }

  /// Maps one block that sits at message-level ordinal [index], which names
  /// parts without a backend identity of their own (text, thinking, images).
  PluginMessagePart mapPart({
    required ClaudeMappedContentBlock block,
    required int index,
    required String sessionId,
    required String messageId,
  }) {
    final fallbackId = "$messageId-block-$index";
    return switch (block) {
      ClaudeMappedTextContentBlock(:final text) ||
      ClaudeMappedTaskNotificationContentBlock(:final text) => PluginMessagePart.text(
        id: fallbackId,
        sessionID: sessionId,
        messageID: messageId,
        text: text,
      ),
      ClaudeMappedThinkingContentBlock(:final thinking) => PluginMessagePart.reasoning(
        id: fallbackId,
        sessionID: sessionId,
        messageID: messageId,
        text: thinking,
      ),
      ClaudeMappedToolUseContentBlock(:final id, :final name, :final input) => PluginMessagePart.tool(
        id: id,
        sessionID: sessionId,
        messageID: messageId,
        tool: name,
        kind: ClaudeToolKindMapper.map(name: name),
        state: PluginToolState(
          status: PluginToolStatus.pending,
          title: ClaudeToolTitleMapper.map(input: input),
          shellCommand: ClaudeShellCommandMapper.map(name: name, input: input),
          output: null,
          error: null,
          attachments: const [],
        ),
      ),
      ClaudeMappedToolResultContentBlock(:final toolUseId, :final output, :final isError, :final attachments) =>
        PluginMessagePart.tool(
          id: toolUseId,
          sessionID: sessionId,
          messageID: messageId,
          tool: null,
          // A result names no tool; replay and live dispatch merge it onto its call, whose kind stays.
          kind: PluginToolKind.other,
          state: PluginToolState(
            status: isError ? PluginToolStatus.error : PluginToolStatus.completed,
            title: null,
            shellCommand: null,
            output: isError ? null : output,
            error: isError ? output : null,
            attachments: attachments,
          ),
        ),
      ClaudeMappedImageContentBlock(:final attachment) => PluginMessagePart.file(
        id: fallbackId,
        sessionID: sessionId,
        messageID: messageId,
        attachment: attachment,
      ),
      ClaudeMappedUnsupportedContentBlock() || ClaudeMappedUnknownContentBlock() => PluginMessagePart.unknown(
        id: fallbackId,
        sessionID: sessionId,
        messageID: messageId,
      ),
    };
  }

  String? _boundedToolOutput(String value) {
    if (value.isEmpty) return null;
    return String.fromCharCodes(value.runes.take(maxToolOutputLength));
  }

  String _normalizedMime(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return "application/octet-stream";
    return String.fromCharCodes(normalized.runes.take(_maxMimeCharacters));
  }
}

final class _ClaudeContentMappingState() {
  int remainingImageBytes = maxTranscriptImageCollectionBytes;
  int _imageCandidates = 0;

  bool takeCandidate() {
    _imageCandidates++;
    return _imageCandidates <= maxTranscriptImageCandidates;
  }
}
