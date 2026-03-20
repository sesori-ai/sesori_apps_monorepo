import "dart:convert";

import "models/sse_event_data.dart";

/// Result of parsing a raw OpenCode SSE event string.
class SseParseResult {
  /// The parsed event, or null if parsing failed.
  final SseEventData? event;

  /// The top-level directory from the OpenCode wrapper, if present.
  final String? directory;

  /// The original raw data string - always preserved for forwarding.
  final String rawData;

  SseParseResult({this.event, this.directory, required this.rawData});
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
/// NEVER throws - all errors are caught internally. On failure, returns
/// a result with null event but preserved rawData for forwarding.
class SseEventParser {
  SseParseResult parse(String rawData) {
    if (rawData.isEmpty) {
      return SseParseResult(rawData: rawData);
    }

    try {
      final json = jsonDecode(rawData) as Map<String, dynamic>;
      final directory = json["directory"] as String?;
      final payload = json["payload"] as Map<String, dynamic>?;
      final type = payload?["type"] as String?;

      if (type == null || payload == null) {
        return SseParseResult(directory: directory, rawData: rawData);
      }

      final properties = payload["properties"] as Map<String, dynamic>? ?? {};
      final merged = <String, dynamic>{"type": type, ...properties};

      final SseEventData event;
      try {
        event = SseEventData.fromJson(merged);
      } catch (_) {
        // Unknown or malformed event type - return null event, preserve raw
        return SseParseResult(directory: directory, rawData: rawData);
      }

      return SseParseResult(
        event: event,
        directory: directory,
        rawData: rawData,
      );
    } catch (_) {
      // JSON decode failure or other unexpected error
      return SseParseResult(rawData: rawData);
    }
  }
}
