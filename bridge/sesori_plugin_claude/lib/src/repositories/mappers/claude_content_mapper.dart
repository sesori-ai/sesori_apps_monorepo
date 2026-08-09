import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart"
    show decodedBase64Length, isInlineMessageAttachmentWithinSizeLimit, maxInlineMessageAttachmentBytes;

import "../../api/models/claude_content_block_dto.dart";

sealed class ClaudeMappedContentBlock {
  const ClaudeMappedContentBlock();
}

final class ClaudeMappedTextContentBlock extends ClaudeMappedContentBlock {
  const ClaudeMappedTextContentBlock({required this.text});

  final String text;
}

final class ClaudeMappedThinkingContentBlock extends ClaudeMappedContentBlock {
  const ClaudeMappedThinkingContentBlock({required this.thinking});

  final String thinking;
}

final class ClaudeMappedToolUseContentBlock extends ClaudeMappedContentBlock {
  const ClaudeMappedToolUseContentBlock({required this.id, required this.name, required this.input});

  final String id;
  final String name;
  final Object? input;
}

final class ClaudeMappedToolResultContentBlock extends ClaudeMappedContentBlock {
  const ClaudeMappedToolResultContentBlock({
    required this.toolUseId,
    required this.output,
    required this.isError,
    required this.attachments,
  });

  final String toolUseId;
  final String? output;
  final bool isError;
  final List<PluginMessageAttachment> attachments;
}

final class ClaudeMappedImageContentBlock extends ClaudeMappedContentBlock {
  const ClaudeMappedImageContentBlock({required this.attachment});

  final PluginMessageAttachment attachment;
}

final class ClaudeMappedUnsupportedContentBlock extends ClaudeMappedContentBlock {
  const ClaudeMappedUnsupportedContentBlock();
}

final class ClaudeMappedUnknownContentBlock extends ClaudeMappedContentBlock {
  const ClaudeMappedUnknownContentBlock();
}

/// Maps Claude's standard Anthropic content blocks into backend-neutral parts.
///
/// This class is stateless. Tool-use correlation and lifecycle remain Step 7's
/// responsibility; the mapped variants retain the identities and input needed
/// there.
final class ClaudeContentMapper {
  const ClaudeContentMapper();

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
    } on Object {
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
        yield ClaudeMappedImageContentBlock(
          attachment: _mapImage(source: source, state: state),
        );
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
    if (!isInlineMessageAttachmentWithinSizeLimit(base64Length: data.length)) {
      return PluginMessageAttachment.metadata(mime: mime, filename: null);
    }

    final String normalized;
    try {
      normalized = base64.normalize(data);
    } on FormatException {
      return PluginMessageAttachment.metadata(mime: mime, filename: null);
    }
    if (!isInlineMessageAttachmentWithinSizeLimit(base64Length: normalized.length)) {
      return PluginMessageAttachment.metadata(mime: mime, filename: null);
    }
    final decodedBytes = decodedBase64Length(base64Data: normalized);
    if (decodedBytes > state.remainingInlineBytes) {
      return PluginMessageAttachment.metadata(mime: mime, filename: null);
    }
    state.remainingInlineBytes -= decodedBytes;
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
    return normalized == null || normalized.isEmpty ? "application/octet-stream" : normalized;
  }
}

final class _ClaudeContentMappingState {
  int remainingInlineBytes = maxInlineMessageAttachmentBytes;
}
