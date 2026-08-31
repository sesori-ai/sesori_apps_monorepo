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

final class PiHistoryMapper({
  required final String pluginId,
}) {
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

  PiAssistantMessageDto? decodeAssistantMessage({required Map<String, Object?> raw}) {
    if (raw["role"] != "assistant") return null;
    return _decodeMessage(raw: raw) as PiAssistantMessageDto?;
  }

  PiUserMessageDto? decodeUserMessage({required Map<String, Object?> raw}) {
    if (raw["role"] != "user") return null;
    return _decodeMessage(raw: raw) as PiUserMessageDto?;
  }

  PiBashExecutionMessageDto? decodeBashExecutionMessage({required Map<String, Object?> raw}) {
    if (raw["role"] != "bashExecution") return null;
    return _decodeMessage(raw: raw) as PiBashExecutionMessageDto?;
  }

  PiCustomMessageDto? decodeCustomMessage({required Map<String, Object?> raw}) {
    if (raw["role"] != "custom") return null;
    return _decodeMessage(raw: raw) as PiCustomMessageDto?;
  }

  PiCustomMessageEntryDto? decodeCustomMessageEntry({required Map<String, Object?> raw}) {
    if (raw["type"] != "custom_message") return null;
    try {
      final entry = PiSessionEntryDto.fromJson(Map<String, dynamic>.from(raw));
      return entry is PiCustomMessageEntryDto ? entry : null;
    } on Object catch (error, stack) {
      Log.w("[pi] appended entry could not be decoded; omitting it", error, stack);
      return null;
    }
  }

  PiAgentMessageDto? _decodeMessage({required Map<String, Object?> raw}) {
    try {
      return PiAgentMessageDto.fromJson(Map<String, dynamic>.from(raw));
    } on Object catch (error, stack) {
      Log.w("[pi] event message could not be decoded; omitting it", error, stack);
      return null;
    }
  }

  PiToolCallContentDto? decodeToolCall({required Map<String, Object?> raw}) {
    try {
      final content = PiContentDto.fromJson({...raw, "type": "toolCall"});
      return content is PiToolCallContentDto ? content : null;
    } on Object catch (error, stack) {
      Log.w("[pi] tool-call event could not be decoded; omitting it", error, stack);
      return null;
    }
  }

  PluginMessageWithParts mapAssistantMessage({
    required String sessionId,
    required String messageId,
    required PiAssistantMessageDto message,
  }) => _mapAssistantMessage(
    sessionId: sessionId,
    messageId: messageId,
    message: message,
    variant: null,
    warnings: <_PiHistoryWarning>{},
  );

  PluginMessageWithParts? mapUserMessage({
    required String sessionId,
    required String messageId,
    required PiUserMessageDto message,
    required String? exactText,
    required String? promptId,
  }) => _mapUserMessage(
    sessionId: sessionId,
    messageId: messageId,
    message: message,
    exactText: exactText,
    promptId: promptId,
    warnings: <_PiHistoryWarning>{},
  );

  PluginMessageWithParts? _mapUserMessage({
    required String sessionId,
    required String messageId,
    required PiUserMessageDto message,
    required String? exactText,
    required String? promptId,
    required Set<_PiHistoryWarning> warnings,
  }) {
    final parts = _mapUserContent(
      content: message.content,
      exactText: exactText,
      sessionId: sessionId,
      messageId: messageId,
      warnings: warnings,
    );
    if (parts.isEmpty) return null;
    return PluginMessageWithParts(
      info: PluginMessage.user(
        id: messageId,
        sessionID: sessionId,
        agent: null,
        time: _time(message.timestamp),
        promptId: promptId,
      ),
      parts: parts,
    );
  }

  PluginMessageWithParts _mapAssistantMessage({
    required String sessionId,
    required String messageId,
    required PiAssistantMessageDto message,
    required String? variant,
    required Set<_PiHistoryWarning> warnings,
  }) {
    final parts = <PluginMessagePart>[];
    for (var index = 0; index < message.content.length; index++) {
      switch (message.content[index]) {
        case PiTextContentDto(:final text) when text.isNotEmpty:
          parts.add(
            PluginMessagePart.text(
              id: "$messageId-block-${index + 1}",
              sessionID: sessionId,
              messageID: messageId,
              text: text,
            ),
          );
        case PiThinkingContentDto(:final thinking, :final redacted) when redacted != true && thinking.isNotEmpty:
          parts.add(
            PluginMessagePart.reasoning(
              id: "$messageId-block-${index + 1}",
              sessionID: sessionId,
              messageID: messageId,
              text: thinking,
            ),
          );
        case PiToolCallContentDto(:final id, :final name):
          parts.add(
            PluginMessagePart.tool(
              id: id,
              sessionID: sessionId,
              messageID: messageId,
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
        case PiUnknownContentDto():
          _warnOnce(reason: _PiHistoryWarning.unknownContent, warnings: warnings);
        case PiImageContentDto() || PiTextContentDto() || PiThinkingContentDto():
          continue;
      }
    }
    return PluginMessageWithParts(
      info: _assistantInfo(
        sessionId: sessionId,
        messageId: messageId,
        provider: message.provider,
        model: message.model,
        variant: variant,
        stopReason: message.stopReason,
        errorMessage: message.errorMessage,
        timestamp: message.timestamp,
      ),
      parts: parts,
    );
  }

  PluginToolState mapToolResult({
    required PiToolResultMessageDto message,
    required PluginToolStatus status,
    required String? title,
  }) {
    final mapped = _mapToolResult(content: message.content, warnings: <_PiHistoryWarning>{});
    return PluginToolState(
      status: status,
      title: title,
      output: message.isError ? null : mapped.output,
      error: message.isError ? mapped.output : null,
      attachments: mapped.attachments,
    );
  }

  PluginToolState? mapLiveToolResult({
    required String toolCallId,
    required String? toolName,
    required Map<String, Object?> result,
    required bool isError,
    required PluginToolStatus status,
    required String? title,
  }) {
    try {
      final message = PiAgentMessageDto.fromJson({
        "role": "toolResult",
        "toolCallId": toolCallId,
        "toolName": toolName ?? "tool",
        "content": result["content"] ?? const [],
        "isError": isError,
        "timestamp": null,
      }) as PiToolResultMessageDto;
      return mapToolResult(message: message, status: status, title: title);
    } on Object catch (error, stack) {
      Log.w("[pi] tool-result event could not be decoded; omitting the update", error, stack);
      return null;
    }
  }

  PluginMessageWithParts mapRunningCompaction({required String sessionId, required String messageId}) => _mapCompaction(
    sessionId: sessionId,
    messageId: messageId,
    title: "Compacting context",
    status: PluginToolStatus.running,
  );

  PluginMessageWithParts mapCompaction({required String sessionId, required String messageId}) => _mapCompaction(
    sessionId: sessionId,
    messageId: messageId,
    title: "Context compacted",
    status: PluginToolStatus.completed,
  );

  PluginMessageWithParts _mapCompaction({
    required String sessionId,
    required String messageId,
    required String title,
    required PluginToolStatus status,
  }) {
    final draft = _toolMessage(
      sessionId: sessionId,
      messageId: messageId,
      timestamp: null,
      tool: "compact",
      title: title,
      output: null,
      error: null,
      status: status,
    );
    return PluginMessageWithParts(info: draft.info, parts: draft.parts);
  }

  PluginMessageWithParts mapBashExecution({
    required String sessionId,
    required String messageId,
    required PiBashExecutionMessageDto message,
  }) {
    final failed = message.cancelled || (message.exitCode != null && message.exitCode != 0);
    final clippedOutput = _clip(message.output);
    final visibleOutput = clippedOutput.isEmpty ? null : clippedOutput;
    final draft = _toolMessage(
      sessionId: sessionId,
      messageId: messageId,
      timestamp: message.timestamp,
      tool: "bash",
      title: _clip(message.command),
      output: failed ? null : visibleOutput,
      error: failed ? visibleOutput : null,
      status: failed ? PluginToolStatus.error : PluginToolStatus.completed,
    );
    return PluginMessageWithParts(info: draft.info, parts: draft.parts);
  }

  PluginMessageWithParts? mapCustomMessage({
    required String sessionId,
    required String messageId,
    required PiCustomMessageDto message,
  }) {
    if (!message.display) return null;
    final text = _visibleCustomText(content: message.content, warnings: <_PiHistoryWarning>{});
    if (text == null) return null;
    final draft = _systemMessage(
      sessionId: sessionId,
      messageId: messageId,
      timestamp: message.timestamp,
      text: text,
    );
    return PluginMessageWithParts(info: draft.info, parts: draft.parts);
  }

  PluginMessageWithParts? mapCustomMessageEntry({
    required String sessionId,
    required String messageId,
    required PiCustomMessageEntryDto entry,
  }) {
    if (!entry.display) return null;
    final text = _visibleCustomText(content: entry.content, warnings: <_PiHistoryWarning>{});
    if (text == null) return null;
    final draft = _systemMessage(sessionId: sessionId, messageId: messageId, timestamp: null, text: text);
    return PluginMessageWithParts(info: draft.info, parts: draft.parts);
  }

  List<PluginMessageWithParts> map({
    required String sessionId,
    required List<PiSessionEntryDto> entries,
    required String? leafId,
    required PiMessageIdentityBuilder identities,
  }) {
    if (leafId == null) return const [];

    final warnings = <_PiHistoryWarning>{};
    final branch = _activeBranch(entries: entries, leafId: leafId, warnings: warnings);
    final messages = <_MessageDraft>[];
    final toolLocations = <String, _ToolLocation>{};
    final terminalToolDrafts = <_MessageDraft>[];
    String? currentVariant;

    for (final entry in branch) {
      switch (entry) {
        case PiMessageEntryDto(:final message):
          switch (message) {
            case final PiUserMessageDto message:
              final messageId = identities.next(role: PiMessageIdentityRole.user, timestamp: message.timestamp);
              final mapped = _mapUserMessage(
                sessionId: sessionId,
                messageId: messageId,
                message: message,
                exactText: null,
                // Replayed history cannot recover the originating prompt id.
                promptId: null,
                warnings: warnings,
              );
              if (mapped != null) messages.add(_MessageDraft(info: mapped.info, parts: mapped.parts.toList()));
            case final PiAssistantMessageDto message:
              final messageId = identities.next(
                role: PiMessageIdentityRole.assistant,
                timestamp: message.timestamp,
              );
              final mapped = _mapAssistantMessage(
                sessionId: sessionId,
                messageId: messageId,
                message: message,
                variant: currentVariant,
                warnings: warnings,
              );
              final draft = _MessageDraft(info: mapped.info, parts: mapped.parts.toList());
              for (var index = 0; index < draft.parts.length; index++) {
                final part = draft.parts[index];
                if (part.type == PluginMessagePartType.tool) {
                  toolLocations[part.id] = _ToolLocation(draft: draft, partIndex: index);
                }
              }
              if (message.stopReason == PiAssistantStopReason.error ||
                  message.stopReason == PiAssistantStopReason.aborted) {
                terminalToolDrafts.add(draft);
              }
              if (draft.parts.isNotEmpty ||
                  message.stopReason == PiAssistantStopReason.error ||
                  message.stopReason == PiAssistantStopReason.aborted) {
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
              final oldPart = location.draft.parts[location.partIndex] as PluginMessagePartTool;
              location.draft.parts[location.partIndex] = oldPart.copyWith(
                state: PluginToolState(
                  status: isError ? PluginToolStatus.error : PluginToolStatus.completed,
                  title: oldPart.state.title,
                  output: isError ? null : mapped.output,
                  error: isError ? mapped.output : null,
                  attachments: mapped.attachments,
                ),
              );
            case final PiBashExecutionMessageDto message:
              final messageId = identities.next(
                role: PiMessageIdentityRole.bashExecution,
                timestamp: message.timestamp,
              );
              final mapped = mapBashExecution(sessionId: sessionId, messageId: messageId, message: message);
              messages.add(_MessageDraft(info: mapped.info, parts: mapped.parts.toList()));
            case final PiCustomMessageDto message:
              final messageId = identities.next(role: PiMessageIdentityRole.custom, timestamp: message.timestamp);
              if (!message.display) continue;
              final text = _visibleCustomText(content: message.content, warnings: warnings);
              if (text == null) continue;
              messages.add(
                _systemMessage(sessionId: sessionId, messageId: messageId, timestamp: message.timestamp, text: text),
              );
            case PiBranchSummaryMessageDto() || PiCompactionSummaryMessageDto():
              continue;
            case PiUnknownMessageDto():
              _warnOnce(reason: _PiHistoryWarning.unknownMessage, warnings: warnings);
          }
        case PiCompactionEntryDto():
          final messageId = identities.nextCompaction();
          final mapped = mapCompaction(sessionId: sessionId, messageId: messageId);
          messages.add(_MessageDraft(info: mapped.info, parts: mapped.parts.toList()));
        case PiCustomMessageEntryDto(:final content, :final display):
          final messageId = identities.nextTopLevelCustomMessage();
          if (!display) continue;
          final text = _visibleCustomText(content: content, warnings: warnings);
          if (text == null) continue;
          messages.add(
            _systemMessage(
              sessionId: sessionId,
              messageId: messageId,
              timestamp: null,
              text: text,
            ),
          );
        case PiUnknownEntryDto():
          _warnOnce(reason: _PiHistoryWarning.unknownEntry, warnings: warnings);
        case PiThinkingLevelChangeEntryDto(:final thinkingLevel):
          currentVariant = thinkingLevel?.wireValue;
          continue;
        case PiModelChangeEntryDto() ||
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
        if (part is! PluginMessagePartTool || part.state.status != PluginToolStatus.pending) continue;
        draft.parts[index] = part.copyWith(
          state: PluginToolState(
            status: PluginToolStatus.error,
            title: part.state.title,
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
    required String? exactText,
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
          final visibleText = exactText ?? _persistedUserTextCodec.decodeVisibleText(persistedText: text);
          if (visibleText.isEmpty) continue;
          parts.add(
            PluginMessagePart.text(
              id: "$messageId-block-${index + 1}",
              sessionID: sessionId,
              messageID: messageId,
              text: visibleText,
            ),
          );
        case PiImageContentDto(:final data, :final mimeType):
          final attachment = _mapImage(data: data, mimeType: mimeType, budget: images, warnings: warnings);
          if (attachment == null) continue;
          parts.add(
            PluginMessagePart.file(
              id: "$messageId-block-${index + 1}",
              sessionID: sessionId,
              messageID: messageId,
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
    final textRunes = <int>[];
    final attachments = <PluginMessageAttachment>[];
    final images = _ImageBudget();
    for (final block in content) {
      switch (block) {
        case PiTextContentDto(text: final value):
          if (textRunes.length < maxToolOutputLength) {
            textRunes.addAll(value.runes.take(maxToolOutputLength - textRunes.length));
          }
        case PiImageContentDto(:final data, :final mimeType):
          final attachment = _mapImage(data: data, mimeType: mimeType, budget: images, warnings: warnings);
          if (attachment != null) attachments.add(attachment);
        case PiUnknownContentDto():
          _warnOnce(reason: _PiHistoryWarning.unknownContent, warnings: warnings);
        case PiThinkingContentDto() || PiToolCallContentDto():
          _warnOnce(reason: _PiHistoryWarning.unsupportedToolContent, warnings: warnings);
      }
    }
    final output = textRunes.isEmpty ? null : String.fromCharCodes(textRunes);
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
    required String? variant,
    required PiAssistantStopReason? stopReason,
    required String? errorMessage,
    required int? timestamp,
  }) {
    return switch (stopReason) {
      PiAssistantStopReason.error => PluginMessage.error(
        id: messageId,
        sessionID: sessionId,
        agent: _pluginId,
        modelID: model,
        providerID: provider,
        variant: variant,
        errorName: "Pi response failed",
        errorMessage: errorMessage ?? "The Pi assistant response failed.",
        time: _time(timestamp),
      ),
      PiAssistantStopReason.aborted => PluginMessage.error(
        id: messageId,
        sessionID: sessionId,
        agent: _pluginId,
        modelID: model,
        providerID: provider,
        variant: variant,
        errorName: "Pi response aborted",
        errorMessage: errorMessage ?? "The Pi assistant response was aborted.",
        time: _time(timestamp),
      ),
      _ => PluginMessage.assistant(
        id: messageId,
        sessionID: sessionId,
        agent: _pluginId,
        modelID: model,
        providerID: provider,
        variant: variant,
        sender: PluginMessageSender.agent,
        time: _time(timestamp),
      ),
    };
  }

  _MessageDraft _systemMessage({
    required String sessionId,
    required String messageId,
    required int? timestamp,
    required String text,
  }) {
    return _MessageDraft(
      info: PluginMessage.assistant(
        id: messageId,
        sessionID: sessionId,
        agent: null,
        modelID: null,
        providerID: null,
        variant: null,
        sender: PluginMessageSender.system,
        time: _time(timestamp),
      ),
      parts: [
        PluginMessagePart.text(
          id: "$messageId-text",
          sessionID: sessionId,
          messageID: messageId,
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
        variant: null,
        sender: PluginMessageSender.agent,
        time: _time(timestamp),
      ),
      parts: [
        PluginMessagePart.tool(
          id: "$messageId-tool",
          sessionID: sessionId,
          messageID: messageId,
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
