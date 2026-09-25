import "claude_task_status.dart";

/// A background task's completion, delivered to the model as a user message
/// whose text is a `<task-notification>` envelope.
///
/// Parsed here once for both the live content mapper and the session
/// service's floor fallback. Only a whole envelope carrying a task id and a
/// status parses. [toolUseId] is absent from some deliveries, which then name
/// no launching call to fold into.
final class const ClaudeTaskNotification({
  required final String taskId,
  required final String? toolUseId,
  required final ClaudeTaskStatus status,
  required final String? summary,
  required final String? result,
}) {
  static const String marker = "<task-notification>";

  static const String _closingMarker = "</task-notification>";

  /// Whether [text] is a whole envelope and nothing else: prose around it is a
  /// prompt that discusses the protocol, not a delivery.
  static bool isEnvelope(String text) {
    final trimmed = text.trim();
    return trimmed.startsWith(marker) && trimmed.endsWith(_closingMarker);
  }

  static ClaudeTaskNotification? tryParse(String text) {
    if (!isEnvelope(text)) return null;
    final taskId = _tag(text, "task-id");
    final status = _tag(text, "status");
    if (taskId == null || status == null) return null;
    return ClaudeTaskNotification(
      taskId: taskId,
      toolUseId: _tag(text, "tool-use-id"),
      status: ClaudeTaskStatus.parse(status),
      summary: _tag(text, "summary"),
      result: _tag(text, "result"),
    );
  }

  static String? _tag(String text, String name) {
    final match = RegExp("<$name>(.*?)</$name>", dotAll: true).firstMatch(text);
    final value = match?.group(1)?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
