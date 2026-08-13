import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart"
    show
        decodedBase64Length,
        isTranscriptImageBase64LengthWithinSizeLimit,
        maxTranscriptImageBytes,
        maxTranscriptImageCandidates,
        maxTranscriptImageCollectionBytes;

import "../../api/models/pi_session_history_dto.dart";
import "../../models/pi_assistant_stop_reason.dart";
import "pi_message_identity_builder.dart";
import "pi_persisted_user_text_codec.dart";

final class PiHistoryMapper({required final String pluginId}) {
  static const _supportedRasterMimes = {
    "image/bmp",
    "image/gif",
    "image/jpeg",
    "image/png",
    "image/webp",
  };
  static const _unfinishedToolError = "Pi tool call did not complete.";

  final PiPersistedUserTextCodec _persistedUserTextCodec = const PiPersistedUserTextCodec();
  final String _pluginId = pluginId;

  List<PluginMessageWithParts> map({
    required String sessionId,
    required List<PiSessionEntryDto> entries,
    required String? leafId,
  }) {
    if (leafId == null) return const [];

    final warnings = <_PiHistoryWarning>{};
    final branch = _activeBranch(entries: entries, leafId: leafId, warnings: warnings);
    final messages = <_MessageDraft>[];
    final toolLocations = <String, _ToolLocation>{};
    final terminalToolDrafts = <_MessageDraft>[];
    final identities = PiMessageIdentityBuilder(pluginId: _pluginId, sessionId: sessionId);

    for (final entry in branch) {
      switch (entry) {
        case PiMessageEntryDto(:final message):
          switch (message) {
            case PiUserMessageDto(:final content, :final timestamp):
              final messageId = identities.next(role: PiMessageIdentityRole.user, timestamp: timestamp);
              final parts = _mapUserContent(
                content: content,
                sessionId: sessionId,
                messageId: messageId,
                warnings: warnings,
              );
              if (parts.isEmpty) continue;
              messages.add(
                _MessageDraft(
                  info: PluginMessage.user(
                    id: messageId,
                    sessionID: sessionId,
                    agent: null,
                    time: _time(timestamp),
                  ),
                  parts: parts,
                ),
              );
            case PiAssistantMessageDto(
              :final content,
              :final provider,
              :final model,
              :final stopReason,
              :final timestamp,
            ):
              final messageId = identities.next(role: PiMessageIdentityRole.assistant, timestamp: timestamp);
              final draft = _MessageDraft(
                info: _assistantInfo(
                  sessionId: sessionId,
                  messageId: messageId,
                  provider: provider,
                  model: model,
                  stopReason: stopReason,
                  timestamp: timestamp,
                ),
                parts: [],
              );
              for (var index = 0; index < content.length; index++) {
                final block = content[index];
                switch (block) {
                  case PiTextContentDto(:final text) when text.isNotEmpty:
                    draft.parts.add(
                      _part(
                        id: "$messageId-block-${index + 1}",
                        sessionId: sessionId,
                        messageId: messageId,
                        type: PluginMessagePartType.text,
                        text: text,
                      ),
                    );
                  case PiThinkingContentDto(:final thinking, :final redacted)
                      when redacted != true && thinking.isNotEmpty:
                    draft.parts.add(
                      _part(
                        id: "$messageId-block-${index + 1}",
                        sessionId: sessionId,
                        messageId: messageId,
                        type: PluginMessagePartType.reasoning,
                        text: thinking,
                      ),
                    );
                  case PiToolCallContentDto(:final id, :final name):
                    final partIndex = draft.parts.length;
                    draft.parts.add(
                      _part(
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
                    );
                    toolLocations[id] = _ToolLocation(draft: draft, partIndex: partIndex);
                  case PiUnknownContentDto():
                    _warnOnce(reason: _PiHistoryWarning.unknownContent, warnings: warnings);
                  case PiImageContentDto() || PiTextContentDto() || PiThinkingContentDto():
                    continue;
                }
              }
              if (stopReason == PiAssistantStopReason.error || stopReason == PiAssistantStopReason.aborted) {
                terminalToolDrafts.add(draft);
              }
              if (draft.parts.isNotEmpty ||
                  stopReason == PiAssistantStopReason.error ||
                  stopReason == PiAssistantStopReason.aborted) {
                messages.add(draft);
              }
            case PiToolResultMessageDto(
              :final toolCallId,
              :final content,
              :final isError,
            ):
              final location = toolLocations[toolCallId];
              if (location == null) continue;
              final mapped = _mapToolResult(content: content, warnings: warnings);
              final oldPart = location.draft.parts[location.partIndex];
              location.draft.parts[location.partIndex] = oldPart.copyWith(
                state: PluginToolState(
                  status: isError ? PluginToolStatus.error : PluginToolStatus.completed,
                  title: oldPart.state?.title,
                  output: isError ? null : mapped.output,
                  error: isError ? mapped.output : null,
                  attachments: mapped.attachments,
                ),
              );
            case PiBashExecutionMessageDto(
              :final command,
              :final output,
              :final exitCode,
              :final cancelled,
              :final timestamp,
            ):
              final messageId = identities.next(role: PiMessageIdentityRole.bashExecution, timestamp: timestamp);
              final failed = cancelled || (exitCode != null && exitCode != 0);
              final clippedOutput = _clip(output);
              messages.add(
                _toolMessage(
                  sessionId: sessionId,
                  messageId: messageId,
                  timestamp: timestamp,
                  tool: "bash",
                  title: command,
                  output: failed ? null : clippedOutput,
                  error: failed ? clippedOutput : null,
                  status: failed ? PluginToolStatus.error : PluginToolStatus.completed,
                ),
              );
            case PiCustomMessageDto(:final content, :final display, :final timestamp):
              final messageId = identities.next(role: PiMessageIdentityRole.custom, timestamp: timestamp);
              if (!display) continue;
              final text = _visibleCustomText(content: content, warnings: warnings);
              if (text == null) continue;
              messages.add(
                _textMessage(
                  sessionId: sessionId,
                  messageId: messageId,
                  timestamp: timestamp,
                  text: text,
                ),
              );
            case PiBranchSummaryMessageDto() || PiCompactionSummaryMessageDto():
              continue;
            case PiUnknownMessageDto():
              _warnOnce(reason: _PiHistoryWarning.unknownMessage, warnings: warnings);
          }
        case PiCompactionEntryDto():
          final messageId = identities.nextCompaction();
          messages.add(
            _toolMessage(
              sessionId: sessionId,
              messageId: messageId,
              timestamp: null,
              tool: "compact",
              title: "Context compacted",
              output: null,
              error: null,
              status: PluginToolStatus.completed,
            ),
          );
        case PiCustomMessageEntryDto(:final content, :final display):
          final messageId = identities.nextTopLevelCustomMessage();
          if (!display) continue;
          final text = _visibleCustomText(content: content, warnings: warnings);
          if (text == null) continue;
          messages.add(
            _textMessage(
              sessionId: sessionId,
              messageId: messageId,
              timestamp: null,
              text: text,
            ),
          );
        case PiUnknownEntryDto():
          _warnOnce(reason: _PiHistoryWarning.unknownEntry, warnings: warnings);
        case PiThinkingLevelChangeEntryDto() ||
            PiModelChangeEntryDto() ||
            PiBranchSummaryEntryDto() ||
            PiCustomEntryDto() ||
            PiLabelEntryDto() ||
            PiSessionInfoEntryDto():
          continue;
      }
    }

    for (final draft in terminalToolDrafts) {
      for (var index = 0; index < draft.parts.length; index++) {
        final part = draft.parts[index];
        if (part.type != PluginMessagePartType.tool || part.state?.status != PluginToolStatus.pending) continue;
        draft.parts[index] = part.copyWith(
          state: PluginToolState(
            status: PluginToolStatus.error,
            title: part.state?.title,
            output: null,
            error: _unfinishedToolError,
            attachments: const [],
          ),
        );
      }
    }

    return [for (final message in messages) PluginMessageWithParts(info: message.info, parts: message.parts)];
  }

  List<PiSessionEntryDto> _activeBranch({
    required List<PiSessionEntryDto> entries,
    required String leafId,
    required Set<_PiHistoryWarning> warnings,
  }) {
    final byId = {for (final entry in entries) entry.id: entry};
    var currentId = leafId;
    if (!byId.containsKey(currentId)) {
      _warnOnce(reason: _PiHistoryWarning.invalidBranch, warnings: warnings);
      if (entries.isEmpty) return const [];
      currentId = entries.last.id;
    }

    final reversed = <PiSessionEntryDto>[];
    final visited = <String>{};
    while (true) {
      if (!visited.add(currentId)) {
        _warnOnce(reason: _PiHistoryWarning.invalidBranch, warnings: warnings);
        break;
      }
      final entry = byId[currentId];
      if (entry == null) {
        _warnOnce(reason: _PiHistoryWarning.invalidBranch, warnings: warnings);
        break;
      }
      reversed.add(entry);
      final parentId = entry.parentId;
      if (parentId == null) break;
      currentId = parentId;
    }
    return reversed.reversed.toList(growable: false);
  }

  List<PluginMessagePart> _mapUserContent({
    required List<PiContentDto> content,
    required String sessionId,
    required String messageId,
    required Set<_PiHistoryWarning> warnings,
  }) {
    final parts = <PluginMessagePart>[];
    final images = _ImageBudget();
    for (var index = 0; index < content.length; index++) {
      final block = content[index];
      switch (block) {
        case PiTextContentDto(:final text):
          final visibleText = _persistedUserTextCodec.decodeVisibleText(persistedText: text);
          if (visibleText.isEmpty) continue;
          parts.add(
            _part(
              id: "$messageId-block-${index + 1}",
              sessionId: sessionId,
              messageId: messageId,
              type: PluginMessagePartType.text,
              text: visibleText,
            ),
          );
        case PiImageContentDto(:final data, :final mimeType):
          final attachment = _mapImage(data: data, mimeType: mimeType, budget: images, warnings: warnings);
          if (attachment == null) continue;
          parts.add(
            _part(
              id: "$messageId-block-${index + 1}",
              sessionId: sessionId,
              messageId: messageId,
              type: PluginMessagePartType.file,
              attachment: attachment,
            ),
          );
        case PiUnknownContentDto():
          _warnOnce(reason: _PiHistoryWarning.unknownContent, warnings: warnings);
        case PiThinkingContentDto() || PiToolCallContentDto():
          _warnOnce(reason: _PiHistoryWarning.unsupportedUserContent, warnings: warnings);
      }
    }
    return parts;
  }

  _MappedToolResult _mapToolResult({
    required List<PiContentDto> content,
    required Set<_PiHistoryWarning> warnings,
  }) {
    final text = StringBuffer();
    final attachments = <PluginMessageAttachment>[];
    final images = _ImageBudget();
    for (final block in content) {
      switch (block) {
        case PiTextContentDto(text: final value):
          text.write(value);
        case PiImageContentDto(:final data, :final mimeType):
          final attachment = _mapImage(data: data, mimeType: mimeType, budget: images, warnings: warnings);
          if (attachment != null) attachments.add(attachment);
        case PiUnknownContentDto():
          _warnOnce(reason: _PiHistoryWarning.unknownContent, warnings: warnings);
        case PiThinkingContentDto() || PiToolCallContentDto():
          _warnOnce(reason: _PiHistoryWarning.unsupportedToolContent, warnings: warnings);
      }
    }
    final output = text.isEmpty ? null : _clip(text.toString());
    return _MappedToolResult(output: output, attachments: attachments);
  }

  PluginMessageAttachment? _mapImage({
    required String data,
    required String mimeType,
    required _ImageBudget budget,
    required Set<_PiHistoryWarning> warnings,
  }) {
    if (budget.candidates >= maxTranscriptImageCandidates) {
      _warnOnce(reason: _PiHistoryWarning.imageCount, warnings: warnings);
      return null;
    }
    budget.candidates++;
    final mime = _normalizeMime(mimeType);
    if (!_supportedRasterMimes.contains(mime)) {
      return PluginMessageAttachment.metadata(mime: mime, filename: null);
    }
    if (data.isEmpty || !isTranscriptImageBase64LengthWithinSizeLimit(base64Length: data.length)) {
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
    if (decodedBytes > maxTranscriptImageBytes ||
        budget.decodedBytes + decodedBytes > maxTranscriptImageCollectionBytes) {
      return PluginMessageAttachment.metadata(mime: mime, filename: null);
    }
    budget.decodedBytes += decodedBytes;
    return PluginMessageAttachment.inlineImage(mime: mime, base64: normalized, filename: null);
  }

  String _normalizeMime(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return "application/octet-stream";
    return String.fromCharCodes(trimmed.runes.take(255)).split(";").first.trim();
  }

  String? _visibleCustomText({
    required List<PiContentDto> content,
    required Set<_PiHistoryWarning> warnings,
  }) {
    final texts = <String>[];
    for (final block in content) {
      switch (block) {
        case PiTextContentDto(:final text) when text.isNotEmpty:
          texts.add(text);
        case PiUnknownContentDto():
          _warnOnce(reason: _PiHistoryWarning.unknownContent, warnings: warnings);
        case PiTextContentDto() || PiImageContentDto() || PiThinkingContentDto() || PiToolCallContentDto():
          continue;
      }
    }
    return texts.isEmpty ? null : texts.join();
  }

  PluginMessage _assistantInfo({
    required String sessionId,
    required String messageId,
    required String? provider,
    required String? model,
    required PiAssistantStopReason? stopReason,
    required int? timestamp,
  }) {
    return switch (stopReason) {
      PiAssistantStopReason.error => PluginMessage.error(
        id: messageId,
        sessionID: sessionId,
        agent: _pluginId,
        modelID: model,
        providerID: provider,
        errorName: "Pi response failed",
        errorMessage: "The Pi assistant response failed.",
        time: _time(timestamp),
      ),
      PiAssistantStopReason.aborted => PluginMessage.error(
        id: messageId,
        sessionID: sessionId,
        agent: _pluginId,
        modelID: model,
        providerID: provider,
        errorName: "Pi response aborted",
        errorMessage: "The Pi assistant response was aborted.",
        time: _time(timestamp),
      ),
      _ => PluginMessage.assistant(
        id: messageId,
        sessionID: sessionId,
        agent: _pluginId,
        modelID: model,
        providerID: provider,
        time: _time(timestamp),
      ),
    };
  }

  _MessageDraft _textMessage({
    required String sessionId,
    required String messageId,
    required int? timestamp,
    required String text,
  }) {
    return _MessageDraft(
      info: PluginMessage.assistant(
        id: messageId,
        sessionID: sessionId,
        agent: _pluginId,
        modelID: null,
        providerID: null,
        time: _time(timestamp),
      ),
      parts: [
        _part(
          id: "$messageId-text",
          sessionId: sessionId,
          messageId: messageId,
          type: PluginMessagePartType.text,
          text: text,
        ),
      ],
    );
  }

  _MessageDraft _toolMessage({
    required String sessionId,
    required String messageId,
    required int? timestamp,
    required String tool,
    required String? title,
    required String? output,
    required String? error,
    required PluginToolStatus status,
  }) {
    return _MessageDraft(
      info: PluginMessage.assistant(
        id: messageId,
        sessionID: sessionId,
        agent: _pluginId,
        modelID: null,
        providerID: null,
        time: _time(timestamp),
      ),
      parts: [
        _part(
          id: "$messageId-tool",
          sessionId: sessionId,
          messageId: messageId,
          type: PluginMessagePartType.tool,
          tool: tool,
          state: PluginToolState(
            status: status,
            title: title,
            output: output,
            error: error,
            attachments: const [],
          ),
        ),
      ],
    );
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
  }) {
    return PluginMessagePart(
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
  }

  PluginMessageTime? _time(int? timestamp) => timestamp == null
      ? null
      : PluginMessageTime(
          created: timestamp,
          completed: null,
        );

  String _clip(String value) => String.fromCharCodes(value.runes.take(maxToolOutputLength));

  void _warnOnce({
    required _PiHistoryWarning reason,
    required Set<_PiHistoryWarning> warnings,
  }) {
    if (!warnings.add(reason)) return;
    Log.w(reason.message);
  }
}

final class _MessageDraft({required final PluginMessage info, required final List<PluginMessagePart> parts});

final class _ToolLocation({required final _MessageDraft draft, required final int partIndex});

final class _MappedToolResult({
  required final String? output,
  required final List<PluginMessageAttachment> attachments,
});

final class _ImageBudget() {
  int candidates = 0;
  int decodedBytes = 0;
}

enum _PiHistoryWarning(final String message) {
  unknownEntry("[pi] history contains unknown entry types; omitting them"),
  unknownMessage("[pi] history contains unknown message roles; omitting them"),
  unknownContent("[pi] history contains unknown content blocks; omitting them"),
  unsupportedUserContent("[pi] history contains unsupported user content blocks; omitting them"),
  unsupportedToolContent("[pi] history contains unsupported tool-result blocks; omitting them"),
  imageCount("[pi] history image collection exceeds count limit; omitting excess images"),
  invalidBranch("[pi] history active branch is incomplete; mapping reachable entries only");
}
