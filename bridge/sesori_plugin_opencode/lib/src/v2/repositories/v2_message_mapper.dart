import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart"
    show
        decodedBase64Length,
        isTranscriptImageBase64LengthWithinSizeLimit,
        maxTranscriptImageBytes,
        maxTranscriptImageCandidates,
        maxTranscriptImageCollectionBytes;

import "../models/openapi/prompt_file_attachment.g.dart";
import "../models/openapi/session_message_agent_selected.g.dart";
import "../models/openapi/session_message_assistant.g.dart";
import "../models/openapi/session_message_assistant_content.g.dart";
import "../models/openapi/session_message_assistant_reasoning.g.dart";
import "../models/openapi/session_message_assistant_text.g.dart";
import "../models/openapi/session_message_assistant_tool.g.dart";
import "../models/openapi/session_message_compaction_completed.g.dart";
import "../models/openapi/session_message_compaction_failed.g.dart";
import "../models/openapi/session_message_compaction_running.g.dart";
import "../models/openapi/session_message_info.g.dart";
import "../models/openapi/session_message_shell.g.dart";
import "../models/openapi/session_message_synthetic.g.dart";
import "../models/openapi/session_message_tool_state.g.dart";
import "../models/openapi/session_message_tool_state_completed.g.dart";
import "../models/openapi/session_message_tool_state_error.g.dart";
import "../models/openapi/session_message_tool_state_running.g.dart";
import "../models/openapi/session_message_tool_state_streaming.g.dart";
import "../models/openapi/session_message_user.g.dart";
import "../models/openapi/tool_content.g.dart";
import "../models/openapi/tool_file_content.g.dart";
import "../models/openapi/tool_text_content.g.dart";
import "../models/v2_agent_names.dart";
import "../models/v2_decode_exception.dart";
import "../models/v2_tool_presentation_fields.dart";

/// Stateless transcript projection. These same part identities and tool-state
/// conversions are reusable by the live-event mapper; no transcript cache exists.
class const V2MessageMapper() {
  static const _rasterMimeTypes = {"image/bmp", "image/gif", "image/jpeg", "image/png", "image/webp"};

  // Preserve the native sortable prefix. Its generated body has no underscores,
  // so this suffix restores prompt correlation through events and history alike.
  static const _promptMarker = "_sesori_";
  static String withPromptId({required String messageId, required String promptId}) =>
      "$messageId$_promptMarker$promptId";
  static String? promptIdForMessage({required String messageId}) {
    final index = messageId.indexOf(_promptMarker);
    return index < 0 ? null : messageId.substring(index + _promptMarker.length);
  }

  static String partId({required String messageId, required int ordinal}) => "$messageId:$ordinal";

  static String retryPartId({required String messageId}) => "$messageId:retry";

  PluginMessageWithParts? mapMessage({
    required String sessionId,
    required SessionMessageInfo message,
    required V2AgentNames agentNames,
  }) {
    final PluginMessage info;
    final List<PluginMessagePart> parts;
    switch (message) {
      case SessionMessageUser():
        info = PluginMessage.user(
          id: message.id,
          sessionID: sessionId,
          agent: null,
          time: PluginMessageTime(created: message.time.created.toInt(), completed: null),
          promptId: promptIdForMessage(messageId: message.id),
        );
        parts = [
          PluginMessagePart.text(
            id: partId(messageId: message.id, ordinal: 0),
            sessionID: sessionId,
            messageID: message.id,
            text: message.text,
          ),
          for (final (index, file) in (message.files ?? const <PromptFileAttachment>[]).indexed)
            PluginMessagePart.file(
              id: partId(messageId: message.id, ordinal: index + 1),
              sessionID: sessionId,
              messageID: message.id,
              attachment: _inlineImage(mime: file.mime, data: file.data, name: file.name),
            ),
          for (final (index, agent) in (message.agents ?? const []).indexed)
            PluginMessagePart.agent(
              id: partId(messageId: message.id, ordinal: (message.files?.length ?? 0) + index + 1),
              sessionID: sessionId,
              messageID: message.id,
              agentName: agentNames.displayName(id: agent.name),
            ),
        ];
      case SessionMessageAssistant():
        final error = message.error;
        final time = PluginMessageTime(
          created: message.time.created.toInt(),
          completed: message.time.completed?.toInt(),
        );
        final agent = agentNames.displayName(id: message.agent);
        info = error == null
            ? PluginMessage.assistant(
                id: message.id,
                sessionID: sessionId,
                agent: agent,
                modelID: message.model.id,
                providerID: message.model.providerID,
                variant: message.model.variant,
                sender: PluginMessageSender.agent,
                time: time,
              )
            : PluginMessage.error(
                id: message.id,
                sessionID: sessionId,
                agent: agent,
                modelID: message.model.id,
                providerID: message.model.providerID,
                variant: message.model.variant,
                time: time,
                errorName: error.type,
                errorMessage: error.message,
              );
        parts = [
          for (final (ordinal, content) in message.content.indexed)
            ?mapContent(sessionId: sessionId, messageId: message.id, ordinal: ordinal, content: content),
          if (message.retry case final retry?)
            PluginMessagePart.retry(
              id: retryPartId(messageId: message.id),
              sessionID: sessionId,
              messageID: message.id,
              attempt: retry.attempt,
              retryError: retry.error.message,
            ),
        ];
      case SessionMessageAgentSelected():
        info = _systemMessage(
          sessionId: sessionId,
          id: message.id,
          created: message.time.created,
          completed: message.time.created,
        );
        parts = [
          PluginMessagePart.agent(
            id: partId(messageId: message.id, ordinal: 0),
            sessionID: sessionId,
            messageID: message.id,
            agentName: agentNames.displayName(id: message.agent),
          ),
        ];
      case SessionMessageSynthetic():
        info = _systemMessage(
          sessionId: sessionId,
          id: message.id,
          created: message.time.created,
          completed: message.time.created,
        );
        parts = [
          PluginMessagePart.text(
            id: partId(messageId: message.id, ordinal: 0),
            sessionID: sessionId,
            messageID: message.id,
            text: message.description ?? message.text,
          ),
        ];
      case SessionMessageCompactionCompleted():
        info = _systemMessage(
          sessionId: sessionId,
          id: message.id,
          created: message.time.created,
          completed: message.time.created,
        );
        parts = [
          PluginMessagePart.compaction(
            id: partId(messageId: message.id, ordinal: 0),
            sessionID: sessionId,
            messageID: message.id,
            summary: message.summary,
          ),
        ];
      case SessionMessageCompactionRunning():
        info = _systemMessage(sessionId: sessionId, id: message.id, created: message.time.created, completed: null);
        // A partial summary is not a completed compaction marker.
        parts = const [];
      case SessionMessageCompactionFailed():
        info = PluginMessage.error(
          id: message.id,
          sessionID: sessionId,
          agent: null,
          modelID: null,
          providerID: null,
          variant: null,
          errorName: message.error.type,
          errorMessage: message.error.message,
          time: PluginMessageTime(created: message.time.created.toInt(), completed: message.time.created.toInt()),
        );
        parts = const [];
      case SessionMessageShell():
        info = _systemMessage(
          sessionId: sessionId,
          id: message.id,
          created: message.time.created,
          completed: message.time.completed,
        );
        parts = [
          PluginMessagePart.tool(
            id: message.shellID,
            sessionID: sessionId,
            messageID: message.id,
            tool: "shell",
            kind: PluginToolKind.command,
            state: PluginToolState(
              status: switch (message.status) {
                SessionMessageShellStatus.running => PluginToolStatus.running,
                SessionMessageShellStatus.exited => switch (message.exit) {
                  0 => PluginToolStatus.completed,
                  num() => PluginToolStatus.error,
                  _ => PluginToolStatus.unknown,
                },
                SessionMessageShellStatus.timeout => PluginToolStatus.error,
                SessionMessageShellStatus.killed => PluginToolStatus.cancelled,
                SessionMessageShellStatus.unknown => PluginToolStatus.unknown,
              },
              title: null,
              shellCommand: message.command,
              output: _truncate(text: message.output?.output),
              error: message.status == SessionMessageShellStatus.timeout ? "Shell command timed out" : null,
              attachments: const [],
            ),
          ),
        ];
      default:
        Log.w("OpenCode v2 transcript contains an unsupported message variant; omitting that message");
        return null;
    }
    return PluginMessageWithParts(
      info: info,
      parts: _boundAttachments(parts: parts),
    );
  }

  PluginMessagePart? mapContent({
    required String sessionId,
    required String messageId,
    required int ordinal,
    required SessionMessageAssistantContent content,
  }) => switch (content) {
    SessionMessageAssistantText() => PluginMessagePart.text(
      id: partId(messageId: messageId, ordinal: ordinal),
      sessionID: sessionId,
      messageID: messageId,
      text: content.text,
    ),
    SessionMessageAssistantReasoning() => PluginMessagePart.reasoning(
      id: partId(messageId: messageId, ordinal: ordinal),
      sessionID: sessionId,
      messageID: messageId,
      text: content.text,
    ),
    SessionMessageAssistantTool() => PluginMessagePart.tool(
      id: content.id,
      sessionID: sessionId,
      messageID: messageId,
      tool: content.name,
      kind: toolKind(name: content.name),
      state: mapToolState(toolName: content.name, state: content.state),
    ),
    _ => _unsupportedContent(),
  };

  PluginToolState mapToolState({required String toolName, required SessionMessageToolState state}) {
    final (status, input, metadata, content, error) = switch (state) {
      SessionMessageToolStateStreaming() => (PluginToolStatus.pending, null, null, const <ToolContent>[], null),
      SessionMessageToolStateRunning() => (
        PluginToolStatus.running,
        state.input,
        state.metadata,
        const <ToolContent>[],
        null,
      ),
      SessionMessageToolStateCompleted() => (
        PluginToolStatus.completed,
        state.input,
        state.metadata,
        state.content,
        null,
      ),
      SessionMessageToolStateError() => (
        PluginToolStatus.error,
        state.input,
        state.metadata,
        state.content ?? const <ToolContent>[],
        state.error.message,
      ),
      _ => (PluginToolStatus.unknown, null, null, const <ToolContent>[], null),
    };
    final text = content.whereType<ToolTextContent>().map((part) => part.text);
    return PluginToolState(
      status: status,
      title: metadata == null ? null : V2ToolPresentationFields.fromJson(metadata).title,
      shellCommand: input == null || toolKind(name: toolName) != PluginToolKind.command
          ? null
          : V2ToolPresentationFields.fromJson(input).command,
      output: text.isEmpty ? null : _truncate(text: text.join("\n")),
      error: error,
      attachments: _limitAttachments(
        attachments: [for (final file in content.whereType<ToolFileContent>()) _toolAttachment(file: file)],
      ),
    );
  }

  PluginToolKind toolKind({required String name}) => switch (name) {
    "read" => PluginToolKind.read,
    "write" || "edit" || "apply_patch" => PluginToolKind.edit,
    "bash" || "shell" => PluginToolKind.command,
    "glob" || "grep" || "webfetch" || "websearch" || "codesearch" => PluginToolKind.search,
    _ => PluginToolKind.other,
  };

  PluginMessage _systemMessage({
    required String sessionId,
    required String id,
    required double created,
    required double? completed,
  }) => PluginMessage.assistant(
    id: id,
    sessionID: sessionId,
    agent: null,
    modelID: null,
    providerID: null,
    variant: null,
    sender: PluginMessageSender.system,
    time: PluginMessageTime(created: created.toInt(), completed: completed?.toInt()),
  );

  PluginMessagePart? _unsupportedContent() {
    Log.w("OpenCode v2 transcript contains unsupported assistant content; omitting that content");
    return null;
  }

  PluginMessageAttachment _inlineImage({required String mime, required String data, required String? name}) {
    final filename = normalizePluginMessageAttachmentFilename(filename: name);
    if (!_rasterMimeTypes.contains(mime) || !isTranscriptImageBase64LengthWithinSizeLimit(base64Length: data.length)) {
      return PluginMessageAttachment.metadata(mime: mime, filename: filename);
    }
    try {
      final normalized = base64.normalize(data);
      if (decodedBase64Length(base64Data: normalized) <= maxTranscriptImageBytes) {
        return PluginMessageAttachment.inlineImage(mime: mime, base64: normalized, filename: filename);
      }
    } on FormatException catch (error, stack) {
      Log.w(
        "OpenCode v2 image is malformed; retaining metadata only",
        V2DecodeException(operation: "attachment", innerError: error),
        stack,
      );
    }
    return PluginMessageAttachment.metadata(mime: mime, filename: filename);
  }

  PluginMessageAttachment _toolAttachment({required ToolFileContent file}) {
    final filename = normalizePluginMessageAttachmentFilename(filename: file.name);
    if (file.uri.startsWith("data:")) {
      // Bound allocation before parsing an embedded image URI.
      if (file.uri.length <= ((maxTranscriptImageBytes + 2) ~/ 3) * 4 + 256) {
        try {
          final data = UriData.parse(file.uri);
          if (data.isBase64 && data.mimeType == file.mime) {
            return _inlineImage(mime: file.mime, data: data.contentText, name: filename);
          }
        } on FormatException catch (error, stack) {
          Log.w(
            "OpenCode v2 image URI is malformed; retaining metadata only",
            V2DecodeException(operation: "attachment URI", innerError: error),
            stack,
          );
        }
      }
    } else if (file.uri.length <= 4096) {
      final uri = Uri.tryParse(file.uri);
      if (uri != null && uri.hasAuthority && uri.userInfo.isEmpty && (uri.scheme == "https" || uri.scheme == "http")) {
        return PluginMessageAttachment.remoteUrl(mime: file.mime, url: uri, filename: filename);
      }
    }
    return PluginMessageAttachment.metadata(mime: file.mime, filename: filename);
  }

  List<PluginMessagePart> _boundAttachments({required List<PluginMessagePart> parts}) {
    final bounded = _limitAttachments(
      attachments: [
        for (final part in parts)
          ...switch (part) {
            PluginMessagePartFile(:final attachment) => [attachment],
            PluginMessagePartTool(:final state) => state.attachments,
            _ => const <PluginMessageAttachment>[],
          },
      ],
    ).iterator;
    PluginMessageAttachment next() {
      bounded.moveNext();
      return bounded.current;
    }

    return [
      for (final part in parts)
        switch (part) {
          PluginMessagePartFile() => part.copyWith(attachment: next()),
          PluginMessagePartTool(:final state) => part.copyWith(
            state: state.copyWith(
              attachments: [for (var i = 0; i < state.attachments.length; i++) next()],
            ),
          ),
          _ => part,
        },
    ];
  }

  List<PluginMessageAttachment> _limitAttachments({required List<PluginMessageAttachment> attachments}) {
    var remaining = maxTranscriptImageCollectionBytes;
    var candidates = 0;
    var overflowCount = 0;
    final bounded = attachments.map((attachment) {
      final bytes = switch (attachment) {
        PluginMessageAttachmentInlineImage(:final base64) => decodedBase64Length(base64Data: base64),
        PluginMessageAttachmentRemoteUrl() => 0,
        PluginMessageAttachmentMetadata() => null,
      };
      if (bytes == null) return attachment;
      if (++candidates > maxTranscriptImageCandidates || bytes > remaining) {
        overflowCount++;
        return PluginMessageAttachment.metadata(mime: attachment.mime, filename: attachment.filename);
      }
      remaining -= bytes;
      return attachment;
    }).toList();
    if (overflowCount > 0) {
      Log.w("OpenCode v2 transcript image budget reached; retaining metadata for $overflowCount attachments");
    }
    return bounded;
  }

  String? _truncate({required String? text}) => text != null && text.length > maxToolOutputLength
      ? String.fromCharCodes(text.runes.take(maxToolOutputLength))
      : text;
}
