import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "api/models/codex_rollout_dto.dart";

class CodexRolloutToolCall {
  const CodexRolloutToolCall({
    required this.id,
    required this.tool,
    required this.title,
  });

  final String id;
  final String tool;
  final String? title;
}

class CodexRolloutToolResult {
  const CodexRolloutToolResult({
    required this.callId,
    required this.status,
    required this.output,
  });

  final String callId;
  final PluginToolStatus status;
  final String? output;
}

/// Pure normalization shared by live rollout enrichment and history replay.
///
/// Codex's stable app-server items intentionally expose a smaller projection
/// than the persisted response items. Keeping the raw call/result rules here
/// prevents the live and reload paths from independently inventing titles,
/// statuses, or output clipping.
class CodexRolloutToolMapper {
  const CodexRolloutToolMapper();

  CodexRolloutToolCall? mapCall(CodexRolloutPayloadDto payload) {
    if (payload.type != CodexRolloutPayloadType.functionCall &&
        payload.type != CodexRolloutPayloadType.customToolCall) {
      return null;
    }
    final id = _usefulText(payload.callId) ?? _usefulText(payload.id);
    if (id == null) return null;
    final name = _usefulText(payload.name) ?? "tool";
    return CodexRolloutToolCall(
      id: id,
      tool: normalizeToolName(name),
      title: toolCallTitle(payload.arguments ?? payload.input),
    );
  }

  CodexRolloutToolResult? mapResult(CodexRolloutPayloadDto payload) {
    if (payload.type != CodexRolloutPayloadType.functionCallOutput &&
        payload.type != CodexRolloutPayloadType.customToolCallOutput) {
      return null;
    }
    final callId = _usefulText(payload.callId);
    if (callId == null) return null;
    final rawOutput = toolOutputText(payload.output);
    return CodexRolloutToolResult(
      callId: callId,
      status: toolOutputStatus(rawOutput),
      output: clipOutput(rawOutput),
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
    return argumentsJson.length > 120 ? argumentsJson.substring(0, 120) : argumentsJson;
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
      for (final item in output ?? const <CodexRolloutContentDto>[])
        if (item.text case final text?
            when (item.type == CodexRolloutContentType.inputText || item.type == CodexRolloutContentType.outputText) &&
                text.isNotEmpty)
          text,
    ];
    return texts.isEmpty ? null : texts.join();
  }

  /// Derives process failure from the executor envelope retained in rollout
  /// output. Merely receiving a tool-output record means the tool returned; it
  /// does not mean the process it observed exited successfully.
  ///
  /// COMPATIBILITY 2026-07-23 (Codex rollout 0.144.x): process exit status is
  /// encoded in human-readable tool output instead of a structured field.
  /// Replace this parser with the structured value once response-item output
  /// exposes one, while continuing to read these strings for old histories.
  PluginToolStatus toolOutputStatus(String? output) {
    if (output == null) return PluginToolStatus.completed;
    final match = RegExp(
      "^(?:Process exited with code|Process exited with exit code|"
      r"Script (?:completed|exited) with (?:code|exit code))\s+(-?\d+)\s*$",
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(output);
    final exitCode = match == null ? null : int.tryParse(match.group(1)!);
    return exitCode != null && exitCode != 0 ? PluginToolStatus.error : PluginToolStatus.completed;
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
