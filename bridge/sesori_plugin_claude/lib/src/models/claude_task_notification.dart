import "claude_task_status.dart";

/// A background task's completion, delivered to the model as a user message
/// whose text is a `<task-notification>` envelope.
///
/// Parsed here once for both the live content mapper and the session
/// service's floor fallback. Only a text that *starts* with the marker and
/// carries every required tag parses; anything else stays ordinary user text.
final class const ClaudeTaskNotification({
  required final String taskId,
  required final String toolUseId,
  required final ClaudeTaskStatus status,
  required final String? summary,
  required final String? result,
}) {
  static const String marker = "<task-notification>";

  static const String _closingMarker = "</task-notification>";

  static ClaudeTaskNotification? tryParse(String text) {
    final trimmed = text.trim();
    // A whole envelope and nothing else: prose around it is a prompt that
    // discusses the protocol, not a delivery.
    if (!trimmed.startsWith(marker) || !trimmed.endsWith(_closingMarker)) return null;
    final taskId = _tag(text, "task-id");
    final toolUseId = _tag(text, "tool-use-id");
    final status = _tag(text, "status");
    if (taskId == null || toolUseId == null || status == null) return null;
    return ClaudeTaskNotification(
      taskId: taskId,
      toolUseId: toolUseId,
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
