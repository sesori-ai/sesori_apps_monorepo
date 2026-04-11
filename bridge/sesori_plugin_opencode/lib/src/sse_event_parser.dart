import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "models/sse_event_data.dart";

enum SseParseOutcome {
  validKnownEvent,
  unknownEventType,
  malformedEnvelope,
  malformedKnownPayload,
}

/// Result of parsing a raw OpenCode SSE event string.
class SseParseResult {
  /// The parsed event, or null if parsing failed.
  final SseEventData? event;

  /// The parsed SSE event type, when it could be extracted from the frame.
  final String? eventType;

  /// The top-level directory from the OpenCode wrapper, if present.
  final String? directory;

  /// The original raw data string - always preserved for forwarding.
  final String rawData;

  /// Categorized parser outcome for callers that need more than null/non-null.
  final SseParseOutcome outcome;

  const SseParseResult({
    required this.outcome,
    this.event,
    this.eventType,
    this.directory,
    required this.rawData,
  });
}

/// Parses raw OpenCode SSE event strings into typed [SseEventData] objects.
///
/// Follows the same extraction logic as the mobile app's
/// `ConnectionService._onSseData`:
/// 1. JSON decode the raw string
/// 2. Extract `payload.type` and `payload.properties`
/// 3. Merge into `{"type": type, ...properties}`
/// 4. Deserialize via `SseEventData.fromJson(merged)`
///
/// Never throws. Callers get categorized outcomes for unknown event types,
/// malformed envelopes, and malformed known payloads while rawData is always
/// preserved for forwarding.
class SseEventParser {
  SseParseResult parse(String rawData) {
    if (rawData.isEmpty) {
      return SseParseResult(
        outcome: SseParseOutcome.malformedEnvelope,
        rawData: rawData,
      );
    }

    try {
      final json = jsonDecodeMap(rawData);
      final directory = json["directory"] as String?;
      final payload = json["payload"];

      if (payload is! Map<String, dynamic>) {
        return SseParseResult(
          outcome: SseParseOutcome.malformedEnvelope,
          directory: directory,
          rawData: rawData,
        );
      }

      final type = payload["type"];
      final eventType = type is String ? type : null;
      final properties = payload["properties"];

      if (type is! String) {
        return SseParseResult(
          outcome: SseParseOutcome.malformedEnvelope,
          directory: directory,
          rawData: rawData,
        );
      }

      if (properties != null && properties is! Map<String, dynamic>) {
        return SseParseResult(
          outcome: SseParseOutcome.malformedEnvelope,
          eventType: eventType,
          directory: directory,
          rawData: rawData,
        );
      }

      if (!_knownEventTypes.contains(type)) {
        return SseParseResult(
          outcome: SseParseOutcome.unknownEventType,
          eventType: eventType,
          directory: directory,
          rawData: rawData,
        );
      }

      try {
        final event = _parseKnownEvent(
          type: type,
          properties: (properties as Map<String, dynamic>?) ?? const <String, dynamic>{},
        );
        return SseParseResult(
          outcome: SseParseOutcome.validKnownEvent,
          event: event,
          eventType: eventType,
          directory: directory,
          rawData: rawData,
        );
      } catch (e) {
        return SseParseResult(
          outcome: SseParseOutcome.malformedKnownPayload,
          eventType: eventType,
          directory: directory,
          rawData: rawData,
        );
      }
    } catch (_) {
      return SseParseResult(
        outcome: SseParseOutcome.malformedEnvelope,
        rawData: rawData,
      );
    }
  }

  SseEventData _parseKnownEvent({required String type, required Map<String, dynamic> properties}) {
    return SseEventData.fromJson({"type": type, ...properties});
  }
}

const Set<String> _knownEventTypes = {
  "server.connected",
  "server.heartbeat",
  "server.instance.disposed",
  "global.disposed",
  "session.created",
  "session.updated",
  "session.deleted",
  "session.diff",
  "session.error",
  "session.compacted",
  "session.status",
  "session.idle",
  "message.updated",
  "message.removed",
  "message.part.updated",
  "message.part.delta",
  "message.part.removed",
  "pty.created",
  "pty.updated",
  "pty.exited",
  "pty.deleted",
  "permission.asked",
  "permission.replied",
  "permission.updated",
  "question.asked",
  "question.replied",
  "question.rejected",
  "todo.updated",
  "project.updated",
  "vcs.branch.updated",
  "file.edited",
  "file.watcher.updated",
  "lsp.updated",
  "lsp.client.diagnostics",
  "mcp.tools.changed",
  "mcp.browser.open.failed",
  "installation.updated",
  "installation.update-available",
  "workspace.ready",
  "workspace.failed",
  "tui.toast.show",
  "worktree.ready",
  "worktree.failed",
};
