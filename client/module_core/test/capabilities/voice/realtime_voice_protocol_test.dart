import "dart:convert";
import "dart:io";

import "package:sesori_dart_core/src/api/models/realtime_voice_protocol.dart";
import "package:test/test.dart";

void main() {
  final fixture =
      jsonDecode(File("test/fixtures/voice_realtime_protocol_v1.json").readAsStringSync()) as Map<String, Object?>;
  final valid = fixture["valid"]! as Map<String, Object?>;
  final invalid = fixture["invalid"]! as Map<String, Object?>;

  test("Given canonical transmitted fixture cases When loaded Then they contain no provider token user or raw project data", () {
    final source = jsonEncode(fixture);

    for (final forbidden in ["accessToken", "soniox", "user_", "sk-", "project-123"]) {
      expect(source, isNot(contains(forbidden)));
    }
    expect(RegExp(r"\bproject-[A-Za-z0-9_-]+\b").hasMatch(source), isFalse);
  });

  test("Given canonical valid cases When parsing protocol v1 Then all client and server messages parse", () {
    for (final entry in valid.entries) {
      final name = entry.key;
      final value = entry.value! as Map<String, Object?>;
      if (name.startsWith("start") || name == "finish" || name == "cancel") {
        expect(parseRealtimeClientMessage(value), isA<RealtimeClientMessage>(), reason: name);
      } else {
        expect(parseRealtimeServerEvent(value), isA<RealtimeVoiceEvent>(), reason: name);
      }
    }
  });

  test("Given canonical invalid cases When parsing protocol v1 Then all malformed messages are rejected", () {
    for (final entry in invalid.entries) {
      final name = entry.key;
      final value = _expandFixtureSentinels(entry.value)! as Map<String, Object?>;
      if (_isClientInvalidCase(name)) {
        expect(() => parseRealtimeClientMessage(value), throwsFormatException, reason: name);
      } else {
        expect(() => parseRealtimeServerEvent(value), throwsFormatException, reason: name);
      }
    }
  });

  test("Given protocol errors When parsing error events Then retryability and close code are fixed", () {
    for (final code in RealtimeVoiceErrorCode.values) {
      final event = parseRealtimeServerEvent({
        "type": "error",
        "code": code.wireName,
        "retryable": code.retryable,
      });

      expect(event, isA<RealtimeVoiceErrorEvent>(), reason: code.wireName);
      expect((event as RealtimeVoiceErrorEvent).closeCode, code.closeCode);
      expect(
        () => parseRealtimeServerEvent({"type": "error", "code": code.wireName, "retryable": !code.retryable}),
        throwsFormatException,
        reason: code.wireName,
      );
    }
  });

  test("Given large daily allowance When parsing ready and complete Then any nonnegative integer is accepted", () {
    final ready = parseRealtimeServerEvent({
      "type": "ready",
      "protocolVersion": 1,
      "maxSessionSeconds": 900,
      "dailySecondsRemaining": 100000,
    });
    final complete = parseRealtimeServerEvent({
      "type": "complete",
      "reason": "finished",
      "dailySecondsRemaining": 100000,
    });

    expect((ready as RealtimeVoiceReadyEvent).dailySecondsRemaining, 100000);
    expect((complete as RealtimeVoiceCompleteEvent).dailySecondsRemaining, 100000);
    expect(
      () => parseRealtimeServerEvent({
        "type": "complete",
        "reason": "finished",
        "dailySecondsRemaining": -1,
      }),
      throwsFormatException,
    );
  });
}

bool _isClientInvalidCase(String name) =>
    name.contains("Start") ||
    name.contains("Protocol") ||
    name.contains("Sample") ||
    name.contains("Encoding") ||
    name.contains("Channels") ||
    name.contains("Project") ||
    name.contains("Control") ||
    name.contains("finish") ||
    name.contains("cancel");

Object? _expandFixtureSentinels(Object? value) {
  if (value == "__TEXT_32769__") return "x" * 32769;
  if (value is List<Object?>) return value.map(_expandFixtureSentinels).toList();
  if (value is Map<String, Object?>) {
    return value.map((key, item) => MapEntry(key, _expandFixtureSentinels(item)));
  }
  return value;
}
