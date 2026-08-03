import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../../api/models/codex_image_bearing_item_dto.dart";
import "../../api/models/codex_rollout_dto.dart";
import "codex_image_attachment_mapper.dart";

class CodexRolloutToolCall {
  const CodexRolloutToolCall({
    required this.id,
    required this.turnId,
    required this.tool,
    required this.title,
  });

  final String id;
  final String? turnId;
  final String tool;
  final String? title;
}

sealed class CodexRolloutToolResult {
  const CodexRolloutToolResult({
    required this.callId,
    required this.output,
    required this.attachments,
  });

  final String callId;
  final String? output;
  final List<PluginMessageAttachment> attachments;

  PluginToolStatus get status => switch (this) {
    CodexRolloutToolRunningResult() => PluginToolStatus.running,
    CodexRolloutToolCompletedResult() => PluginToolStatus.completed,
    CodexRolloutToolErrorResult() || CodexRolloutToolErrorWithRunningCellsResult() => PluginToolStatus.error,
  };
}

final class CodexRolloutToolRunningResult extends CodexRolloutToolResult {
  const CodexRolloutToolRunningResult({
    required super.callId,
    required super.output,
    required super.attachments,
    required this.cellIds,
  });

  final List<String> cellIds;
}

final class CodexRolloutToolCompletedResult extends CodexRolloutToolResult {
  const CodexRolloutToolCompletedResult({
    required super.callId,
    required super.output,
    required super.attachments,
  });
}

final class CodexRolloutToolErrorResult extends CodexRolloutToolResult {
  const CodexRolloutToolErrorResult({
    required super.callId,
    required super.output,
    required super.attachments,
  });
}

final class CodexRolloutToolErrorWithRunningCellsResult extends CodexRolloutToolResult {
  const CodexRolloutToolErrorWithRunningCellsResult({
    required super.callId,
    required super.output,
    required super.attachments,
    required this.cellIds,
  });

  final List<String> cellIds;
}

class CodexRolloutWaitCall {
  const CodexRolloutWaitCall({
    required this.callId,
    required this.turnId,
    required this.cellId,
  });

  final String callId;
  final String? turnId;
  final String cellId;
}

class CodexRolloutImageGeneration {
  const CodexRolloutImageGeneration({
    required this.id,
    required this.status,
    required this.attachments,
  });

  final String? id;
  final PluginToolStatus status;
  final List<PluginMessageAttachment> attachments;
}

/// Pure normalization shared by live rollout enrichment and history replay.
///
/// Codex's stable app-server items intentionally expose a smaller projection
/// than the persisted response items. Keeping the raw call/result rules here
/// prevents the live and reload paths from independently inventing titles,
/// raw result classifications, or attachment extraction.
class CodexRolloutToolMapper {
  const CodexRolloutToolMapper({
    required CodexImageAttachmentMapper imageAttachmentMapper,
  }) : _imageAttachmentMapper = imageAttachmentMapper;

  final CodexImageAttachmentMapper _imageAttachmentMapper;

  /// Whether this persisted function call has a matching stable
  /// `commandExecution` item.
  bool isCommandExecutionCall({
    required CodexRolloutResponseItemDto payload,
  }) {
    return switch (payload) {
      CodexRolloutFunctionCallDto(:final name) => name.toLowerCase() == "exec_command",
      CodexRolloutMessageDto() ||
      CodexRolloutReasoningDto() ||
      CodexRolloutFunctionCallOutputDto() ||
      CodexRolloutCustomToolCallDto() ||
      CodexRolloutCustomToolCallOutputDto() ||
      CodexRolloutWebSearchCallDto() ||
      CodexRolloutImageGenerationDto() ||
      CodexRolloutUnknownResponseItemDto() => false,
    };
  }

  bool isSingleCodeModeCommandExecutionCall({
    required CodexRolloutResponseItemDto payload,
  }) {
    if (payload case CodexRolloutCustomToolCallDto(
      :final name,
      :final input,
    ) when name.toLowerCase() == "exec") {
      const marker = "tools.exec_command(";
      final first = input.indexOf(marker);
      return first >= 0 && input.indexOf(marker, first + marker.length) < 0;
    }
    return false;
  }

  CodexRolloutImageGeneration mapImageGeneration({
    required CodexRolloutImageGenerationDto item,
  }) {
    final status = switch (item.status) {
      CodexRolloutImageGenerationStatus.inProgress => PluginToolStatus.running,
      CodexRolloutImageGenerationStatus.completed => PluginToolStatus.completed,
      CodexRolloutImageGenerationStatus.failed => PluginToolStatus.error,
      // Rollout response items are terminal history. Preserve a valid result
      // when a future Codex version adds another terminal status.
      CodexRolloutImageGenerationStatus.unknown => PluginToolStatus.completed,
    };
    return CodexRolloutImageGeneration(
      id: _usefulText(item.id),
      status: status,
      attachments: status == PluginToolStatus.completed
          ? _imageAttachmentMapper.map(
              candidates: [
                CodexImageAttachmentCandidate.base64(
                  data: item.result,
                  mime: "image/png",
                  filenameHint: null,
                ),
              ],
            )
          : const [],
    );
  }

  CodexRolloutImageGeneration mapImageGenerationEnd({
    required CodexRolloutImageGenerationEndEventDto event,
  }) {
    final status = switch (event.status) {
      CodexRolloutImageGenerationStatus.inProgress => PluginToolStatus.running,
      CodexRolloutImageGenerationStatus.completed => PluginToolStatus.completed,
      CodexRolloutImageGenerationStatus.failed => PluginToolStatus.error,
      CodexRolloutImageGenerationStatus.unknown => PluginToolStatus.completed,
    };
    return CodexRolloutImageGeneration(
      id: _usefulText(event.callId),
      status: status,
      attachments: status == PluginToolStatus.completed
          ? _imageAttachmentMapper.map(
              candidates: [
                CodexImageAttachmentCandidate.base64(
                  data: event.result,
                  mime: "image/png",
                  filenameHint: event.savedPath,
                ),
              ],
            )
          : const [],
    );
  }

  CodexRolloutImageGeneration mapAppServerImageGeneration({
    required CodexImageGenerationItemDto item,
    required bool completed,
  }) {
    final status = switch (item.status) {
      CodexImageGenerationStatus.inProgress => PluginToolStatus.running,
      CodexImageGenerationStatus.completed => PluginToolStatus.completed,
      CodexImageGenerationStatus.failed => PluginToolStatus.error,
      CodexImageGenerationStatus.unknown => completed ? PluginToolStatus.completed : PluginToolStatus.running,
    };
    return CodexRolloutImageGeneration(
      id: _usefulText(item.id),
      status: status,
      attachments: status == PluginToolStatus.completed
          ? _imageAttachmentMapper.map(
              candidates: [
                CodexImageAttachmentCandidate.base64(
                  data: item.result,
                  mime: "image/png",
                  filenameHint: item.savedPath,
                ),
              ],
            )
          : const [],
    );
  }

  List<PluginMessageAttachment> boundAttachments({
    required Iterable<PluginMessageAttachment> attachments,
  }) => _imageAttachmentMapper.boundMappedAttachments(
    attachments: attachments,
  );

  List<PluginMessageAttachment> mapContentAttachments({
    required Iterable<CodexRolloutContentDto> content,
  }) {
    return _imageAttachmentMapper.map(
      candidates: [
        for (final item in content)
          if (item case CodexRolloutInputImageDto(:final imageUrl))
            CodexImageAttachmentCandidate.imageUrl(imageUrl: imageUrl),
      ],
    );
  }

  CodexRolloutToolCall? mapCall(CodexRolloutResponseItemDto payload) {
    if (isInternalToolCall(payload: payload)) return null;
    return switch (payload) {
      CodexRolloutFunctionCallDto(
        :final id,
        :final callId,
        :final name,
        :final arguments,
        :final metadata,
      ) =>
        _mapCall(
          id: id,
          callId: callId,
          turnId: metadata?.turnId,
          name: name,
          input: arguments,
        ),
      CodexRolloutCustomToolCallDto(
        :final id,
        :final callId,
        :final name,
        :final input,
        :final metadata,
      ) =>
        _mapCall(
          id: id,
          callId: callId,
          turnId: metadata?.turnId,
          name: name,
          input: input,
        ),
      CodexRolloutMessageDto() ||
      CodexRolloutReasoningDto() ||
      CodexRolloutFunctionCallOutputDto() ||
      CodexRolloutCustomToolCallOutputDto() ||
      CodexRolloutWebSearchCallDto() ||
      CodexRolloutImageGenerationDto() ||
      CodexRolloutUnknownResponseItemDto() => null,
    };
  }

  bool isInternalToolCall({
    required CodexRolloutResponseItemDto payload,
  }) {
    return switch (payload) {
      CodexRolloutFunctionCallDto(:final name) => name.toLowerCase() == "wait",
      CodexRolloutCustomToolCallDto(:final name, :final input) =>
        name.toLowerCase() == "exec" && _isGeneratedImageInvocation(input),
      CodexRolloutMessageDto() ||
      CodexRolloutReasoningDto() ||
      CodexRolloutFunctionCallOutputDto() ||
      CodexRolloutCustomToolCallOutputDto() ||
      CodexRolloutWebSearchCallDto() ||
      CodexRolloutImageGenerationDto() ||
      CodexRolloutUnknownResponseItemDto() => false,
    };
  }

  CodexRolloutWaitCall? mapWaitCall({
    required CodexRolloutResponseItemDto payload,
  }) {
    if (payload case CodexRolloutFunctionCallDto(
      :final callId,
      :final name,
      :final arguments,
      :final metadata,
    ) when name.toLowerCase() == "wait") {
      final cellId = _tryDecodeToolArguments(raw: arguments)?.cellId;
      final usefulCallId = _usefulText(callId);
      final usefulCellId = _usefulText(cellId?.toString());
      if (usefulCallId != null && usefulCellId != null) {
        return CodexRolloutWaitCall(
          callId: usefulCallId,
          turnId: _usefulText(metadata?.turnId),
          cellId: usefulCellId,
        );
      }
    }
    return null;
  }

  String? internalCallId({
    required CodexRolloutResponseItemDto payload,
  }) {
    if (!isInternalToolCall(payload: payload)) return null;
    return switch (payload) {
      CodexRolloutFunctionCallDto(:final callId) || CodexRolloutCustomToolCallDto(:final callId) => _usefulText(callId),
      CodexRolloutMessageDto() ||
      CodexRolloutReasoningDto() ||
      CodexRolloutFunctionCallOutputDto() ||
      CodexRolloutCustomToolCallOutputDto() ||
      CodexRolloutWebSearchCallDto() ||
      CodexRolloutImageGenerationDto() ||
      CodexRolloutUnknownResponseItemDto() => null,
    };
  }

  CodexRolloutToolCall? _mapCall({
    required String? id,
    required String callId,
    required String? turnId,
    required String name,
    required String input,
  }) {
    final usefulId = _usefulText(callId) ?? _usefulText(id);
    if (usefulId == null) return null;
    final usefulName = _usefulText(name) ?? "tool";
    return CodexRolloutToolCall(
      id: usefulId,
      turnId: _usefulText(turnId),
      tool: normalizeToolName(usefulName),
      title: toolCallTitle(input),
    );
  }

  CodexRolloutToolResult? mapResult(CodexRolloutResponseItemDto payload) {
    final ({String callId, List<CodexRolloutContentDto> content})? output = switch (payload) {
      CodexRolloutFunctionCallOutputDto(:final callId, :final output) ||
      CodexRolloutCustomToolCallOutputDto(:final callId, :final output) => (callId: callId, content: output),
      CodexRolloutMessageDto() ||
      CodexRolloutReasoningDto() ||
      CodexRolloutFunctionCallDto() ||
      CodexRolloutCustomToolCallDto() ||
      CodexRolloutWebSearchCallDto() ||
      CodexRolloutImageGenerationDto() ||
      CodexRolloutUnknownResponseItemDto() => null,
    };
    if (output == null) return null;
    final callId = _usefulText(output.callId);
    if (callId == null) return null;
    final rawOutput = toolOutputText(output.content);
    final attachments = mapContentAttachments(
      content: output.content,
    );
    final cellIds = _runningCellIds(content: output.content);
    final failed = _toolOutputFailed(content: output.content);
    if (cellIds.isNotEmpty) {
      return failed
          ? CodexRolloutToolErrorWithRunningCellsResult(
              callId: callId,
              output: rawOutput,
              attachments: attachments,
              cellIds: cellIds,
            )
          : CodexRolloutToolRunningResult(
              callId: callId,
              output: rawOutput,
              attachments: attachments,
              cellIds: cellIds,
            );
    }
    return failed
        ? CodexRolloutToolErrorResult(
            callId: callId,
            output: rawOutput,
            attachments: attachments,
          )
        : CodexRolloutToolCompletedResult(
            callId: callId,
            output: rawOutput,
            attachments: attachments,
          );
  }

  String normalizeToolName(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains("stdin")) return "shell";
    if (normalized.contains("patch") || normalized.contains("edit") || normalized.contains("write")) {
      return "edit";
    }
    if (normalized.contains("exec") ||
        normalized.contains("shell") ||
        normalized.contains("bash") ||
        normalized.contains("command")) {
      return "shell";
    }
    return name;
  }

  String? toolCallTitle(String? argumentsJson) {
    if (argumentsJson == null || argumentsJson.isEmpty) return null;
    final arguments = _tryDecodeToolArguments(raw: argumentsJson);
    if (arguments != null) {
      for (final value in [
        arguments.cmd,
        arguments.command,
        arguments.path,
        arguments.filePath,
        arguments.query,
      ]) {
        if (value is String && value.isNotEmpty) return value;
        if (value is List && value.isNotEmpty) return value.join(" ");
      }
    }
    final embeddedCommand = _embeddedExecCommand(source: argumentsJson);
    if (embeddedCommand != null && embeddedCommand.isNotEmpty) {
      return embeddedCommand;
    }
    return argumentsJson.runes.length > 120 ? String.fromCharCodes(argumentsJson.runes.take(120)) : argumentsJson;
  }

  /// Removes the launcher added by app-server so the provisional live title
  /// matches the logical `cmd` persisted in the rollout.
  ///
  /// COMPATIBILITY 2026-07-23 (Codex app-server 0.144.x): commandExecution
  /// wraps commands as `<shell> -lc <command>`, while response-item arguments
  /// retain the original command. Remove this normalization when app-server's
  /// stable item title carries the original command itself.
  String? logicalCommandTitle(String? command) {
    final value = _usefulText(command);
    if (value == null) return null;
    final match = RegExp(
      r"^(?:\S*/)?(?:zsh|bash|sh)\s+-lc\s+(.+)$",
    ).firstMatch(value);
    if (match == null) return value;
    final payload = match.group(1)?.trim();
    if (payload == null || payload.isEmpty) return value;
    if (payload.length >= 2) {
      final first = payload[0];
      final last = payload[payload.length - 1];
      if (first == "'" && last == "'") {
        return payload.substring(1, payload.length - 1);
      }
      if (first == '"' && last == '"') {
        try {
          final decoded = jsonDecode(payload);
          if (decoded is String && decoded.isNotEmpty) return decoded;
        } on FormatException {
          // Keep the unparsed payload below; the rollout call will shortly
          // replace it with the authoritative logical command.
        }
      }
    }
    return payload;
  }

  String? toolOutputText(List<CodexRolloutContentDto>? output) {
    final texts = [
      for (final item in output ?? const <CodexRolloutContentDto>[]) ?_toolContentText(content: item),
    ];
    return texts.isEmpty ? null : texts.join();
  }

  String? _toolContentText({required CodexRolloutContentDto content}) {
    return switch (content) {
      CodexRolloutInputTextDto(:final text) || CodexRolloutOutputTextDto(:final text) when text.isNotEmpty => text,
      CodexRolloutInputTextDto() ||
      CodexRolloutOutputTextDto() ||
      CodexRolloutSummaryTextDto() ||
      CodexRolloutInputImageDto() ||
      CodexRolloutUnknownContentDto() => null,
    };
  }

  /// Derives process failure from the executor envelope retained in rollout
  /// output. Merely receiving a tool-output record means the tool returned; it
  /// does not mean the process it observed exited successfully.
  ///
  /// COMPATIBILITY 2026-07-23 (Codex rollout 0.144.x): process exit status is
  /// encoded in human-readable tool output instead of a structured field.
  /// Replace this parser with the structured value once response-item output
  /// exposes one, while continuing to read these strings for old histories.
  bool _toolOutputFailed({
    required List<CodexRolloutContentDto> content,
  }) {
    for (final item in content) {
      final output = _toolContentText(content: item);
      if (output != null && _leadingExecutorEnvelopeFailed(output: output)) {
        return true;
      }
    }
    return false;
  }

  bool _leadingExecutorEnvelopeFailed({required String output}) {
    if (RegExp(r"^aborted by user\b", caseSensitive: false).hasMatch(output)) {
      return true;
    }
    final lines = output.split(RegExp(r"\r?\n"));
    final outputBoundary = lines.indexWhere(
      (line) => RegExp(r"^(?:Final )?Output:\s*$", caseSensitive: false).hasMatch(line),
    );
    final exitPattern = RegExp(
      "^(?:Process exited with code|Process exited with exit code|"
      r"Script (?:completed|exited) with (?:code|exit code))\s+(-?\d+)\s*$",
      caseSensitive: false,
    );
    final metadataPattern = RegExp(
      "^(?:Chunk ID|Wall time):",
      caseSensitive: false,
    );
    final envelope = outputBoundary < 0
        ? lines.takeWhile(
            (line) => line.isEmpty || metadataPattern.hasMatch(line) || exitPattern.hasMatch(line),
          )
        : lines.take(outputBoundary);
    for (final line in envelope) {
      final match = exitPattern.firstMatch(line);
      final exitCode = match == null ? null : int.tryParse(match.group(1)!);
      if (exitCode != null && exitCode != 0) return true;
    }
    return false;
  }

  String? _runningCellId({required String? output}) {
    if (output == null) return null;
    final match = RegExp(
      r"^Script running with cell ID[ \t]+(\S+)[ \t]*(?:\r?\n|$)",
      caseSensitive: false,
    ).firstMatch(output);
    return _usefulText(match?.group(1));
  }

  List<String> _runningCellIds({
    required List<CodexRolloutContentDto> content,
  }) {
    final cellIds = <String>[];
    for (final item in content) {
      final cellId = _runningCellId(
        output: _toolContentText(content: item),
      );
      if (cellId != null && !cellIds.contains(cellId)) cellIds.add(cellId);
    }
    return cellIds;
  }

  String? clipOutput(String? output) {
    if (output == null || output.runes.length <= maxToolOutputLength) {
      return output;
    }
    return String.fromCharCodes(output.runes.take(maxToolOutputLength));
  }

  CodexToolArgumentsDto? _tryDecodeToolArguments({required String raw}) {
    try {
      return CodexToolArgumentsDto.fromJson(jsonDecodeMap(raw));
    } on Object {
      return null;
    }
  }

  String? _embeddedExecCommand({required String source}) {
    const marker = "tools.exec_command(";
    final markerIndex = source.indexOf(marker);
    if (markerIndex < 0) return null;

    final argumentsStart = markerIndex + marker.length;
    final commandMatch = RegExp(
      r'(?:^|[,{]\s*)(?:"cmd"|cmd)\s*:\s*',
    ).firstMatch(source.substring(argumentsStart));
    if (commandMatch == null) return null;
    final valueStart = argumentsStart + commandMatch.end;
    if (valueStart >= source.length || source.codeUnitAt(valueStart) != 0x22) {
      return null;
    }

    var escaped = false;
    for (var index = valueStart + 1; index < source.length; index++) {
      final codeUnit = source.codeUnitAt(index);
      if (escaped) {
        escaped = false;
      } else if (codeUnit == 0x5C) {
        escaped = true;
      } else if (codeUnit == 0x22) {
        try {
          final decoded = jsonDecode(source.substring(valueStart, index + 1));
          return decoded is String ? decoded : null;
        } on FormatException {
          return null;
        }
      }
    }
    return null;
  }

  String? _usefulText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

final RegExp _generatedImageInvocationPattern = RegExp(
  r"^\s*(?:await\s+)?tools\.image_gen__[A-Za-z0-9_]+\s*\([\s\S]*\)\s*;?\s*$",
);

final RegExp _generatedExecDirectivePattern = RegExp(
  r"^\s*//\s*@exec:\s*\{[^\r\n]*\}[ \t]*(?:\r?\n|$)",
);

final RegExp _forwardedGeneratedImageInvocationPattern = RegExp(
  r"^\s*(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*await\s+"
  r"tools\.image_gen__[A-Za-z0-9_]+\s*\([\s\S]*\)\s*;\s*"
  r"generatedImage\(\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*\)\s*;?\s*$",
);

bool _isGeneratedImageInvocation(String input) {
  final directive = _generatedExecDirectivePattern.firstMatch(input);
  final invocation = directive == null ? input : input.substring(directive.end);
  if (_generatedImageInvocationPattern.hasMatch(invocation)) return true;
  final forwarded = _forwardedGeneratedImageInvocationPattern.firstMatch(
    invocation,
  );
  return forwarded != null && forwarded.group(1) == forwarded.group(2);
}
