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

sealed class const ClaudeMappedContentBlock();

final class const ClaudeMappedTextContentBlock({required final String text}) extends ClaudeMappedContentBlock;

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
      return text == null || text.isEmpty ? const <Object?>[] : [{"type": "text", "text": text}];
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

  List<PluginMessagePart> mapParts({
    required Object? content,
    required String sessionId,
    required String messageId,
  }) {
    final blocks = map(content: content);
    return [
      for (var index = 0; index < blocks.length; index++)
        _toPart(block: blocks[index], index: index, sessionId: sessionId, messageId: messageId),
    ];
  }

  Iterable<ClaudeMappedContentBlock> _mapValue({
    required Object? content,
    required _ClaudeContentMappingState state,
  }) sync* {
    if (content == null) return;
    if (content is String) {
      yield ClaudeMappedTextContentBlock(text: content);
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
        yield text == null ? const ClaudeMappedUnknownContentBlock() : ClaudeMappedTextContentBlock(text: text);
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
        case ClaudeMappedTextContentBlock(text: final value):
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

  PluginMessagePart _toPart({
    required ClaudeMappedContentBlock block,
    required int index,
    required String sessionId,
    required String messageId,
  }) {
    final fallbackId = "$messageId-block-$index";
    return switch (block) {
      ClaudeMappedTextContentBlock(:final text) => _part(
        id: fallbackId,
        sessionId: sessionId,
        messageId: messageId,
        type: PluginMessagePartType.text,
        text: text,
      ),
      ClaudeMappedThinkingContentBlock(:final thinking) => _part(
        id: fallbackId,
        sessionId: sessionId,
        messageId: messageId,
        type: PluginMessagePartType.reasoning,
        text: thinking,
      ),
      ClaudeMappedToolUseContentBlock(:final id, :final name) => _part(
        id: id,
        sessionId: sessionId,
        messageId: messageId,
        type: PluginMessagePartType.tool,
        tool: name,
        state: const PluginToolState(
          status: PluginToolStatus.pending,
          title: null,
          output: null,
          error: null,
          attachments: [],
        ),
      ),
      ClaudeMappedToolResultContentBlock(:final toolUseId, :final output, :final isError, :final attachments) => _part(
        id: toolUseId,
        sessionId: sessionId,
        messageId: messageId,
        type: PluginMessagePartType.tool,
        state: PluginToolState(
          status: isError ? PluginToolStatus.error : PluginToolStatus.completed,
          title: null,
          output: isError ? null : output,
          error: isError ? output : null,
          attachments: attachments,
        ),
      ),
      ClaudeMappedImageContentBlock(:final attachment) => _part(
        id: fallbackId,
        sessionId: sessionId,
        messageId: messageId,
        type: PluginMessagePartType.file,
        attachment: attachment,
      ),
      ClaudeMappedUnsupportedContentBlock() || ClaudeMappedUnknownContentBlock() => _part(
        id: fallbackId,
        sessionId: sessionId,
        messageId: messageId,
        type: PluginMessagePartType.unknown,
      ),
    };
  }

  PluginMessagePart _part({
    required String id,
    required String sessionId,
    required String messageId,
    required PluginMessagePartType type,
    String? text,
    String? tool,
    PluginToolState? state,
    PluginMessageAttachment? attachment,
  }) => PluginMessagePart(
    id: id,
    sessionID: sessionId,
    messageID: messageId,
    type: type,
    text: text,
    tool: tool,
    state: state,
    prompt: null,
    description: null,
    agent: null,
    childSessionID: null,
    agentName: null,
    attempt: null,
    retryError: null,
    attachment: attachment,
  );

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
