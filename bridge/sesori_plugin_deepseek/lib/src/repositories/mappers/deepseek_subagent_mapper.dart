import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/deepseek_protocol_dto.dart";

/// Pure projection of DeepSeek's sub-agent protocol into shared child and tile
/// vocabulary, including terminal outcomes and bounded presentation output.
class const DeepSeekSubagentMapper({required final String agentId}) {
  AcpChildSpawn mapStarted({required DeepSeekSubagentStartedDto notification}) => AcpChildSpawn(
    childSessionId: notification.childSessionId,
    description: notification.label,
    agent: agentId,
    prompt: notification.prompt,
    isBackground: notification.mode == DeepSeekSubagentMode.background,
  );

  PluginToolState mapState({
    required DeepSeekSubagentStopReason stopReason,
    required String? summary,
  }) {
    final boundedSummary = _bounded(value: summary);
    return switch (stopReason) {
      DeepSeekSubagentStopReason.completed => PluginToolState(
        status: PluginToolStatus.completed,
        title: null,
        output: boundedSummary,
        error: null,
        attachments: const [],
      ),
      DeepSeekSubagentStopReason.aborted => const PluginToolState(
        status: PluginToolStatus.cancelled,
        title: null,
        output: null,
        error: null,
        attachments: [],
      ),
      DeepSeekSubagentStopReason.error ||
      DeepSeekSubagentStopReason.maxTokens ||
      DeepSeekSubagentStopReason.refusal => PluginToolState(
        status: PluginToolStatus.error,
        title: null,
        output: null,
        error: boundedSummary ?? _errorFor(stopReason: stopReason),
        attachments: const [],
      ),
      DeepSeekSubagentStopReason.unknown => throw const FormatException("Unknown DeepSeek sub-agent stop reason"),
    };
  }

  String? _bounded({required String? value}) =>
      value == null || value.isEmpty ? null : String.fromCharCodes(value.runes.take(maxToolOutputLength));

  String _errorFor({required DeepSeekSubagentStopReason stopReason}) => switch (stopReason) {
    DeepSeekSubagentStopReason.error => "DeepSeek sub-agent failed",
    DeepSeekSubagentStopReason.maxTokens => "DeepSeek sub-agent reached its token limit",
    DeepSeekSubagentStopReason.refusal => "DeepSeek sub-agent declined the task",
    DeepSeekSubagentStopReason.completed ||
    DeepSeekSubagentStopReason.aborted ||
    DeepSeekSubagentStopReason.unknown => throw StateError("DeepSeek sub-agent stop reason is not an error"),
  };
}
