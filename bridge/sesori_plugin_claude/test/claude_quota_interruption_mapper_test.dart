import "package:claude_plugin/claude_plugin.dart";
import "package:claude_plugin/src/repositories/mappers/claude_quota_interruption_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  final mapper = ClaudeQuotaInterruptionMapper(contentMapper: const ClaudeContentMapper());
  final observedAt = DateTime.utc(2026, 9, 23, 14, 12, 51);

  PluginQuotaInterruption? map({required String text, required Map<String, Object?> fields}) => mapper.map(
    message: ClaudeStreamMessage.parse({
      "type": "assistant",
      "uuid": "transcript-uuid",
      "error": "rate_limit",
      "timestamp": observedAt.toIso8601String(),
      "message": {
        "id": "visible-error-id",
        "content": [
          {"type": "text", "text": text},
        ],
      },
      ...fields,
    }) as ClaudeAssistantMessage,
    observedAt: observedAt.add(const Duration(days: 1)),
  );

  test("observed Sofia quota keeps the visible error ID and original UTC time", () {
    final interruption =
        map(text: "You've hit your session limit · resets 6:30pm (Europe/Sofia)", fields: const {}) ??
        fail("quota interruption was not mapped");
    expect(interruption.errorMessageId, "visible-error-id");
    expect(interruption.observedAt, observedAt);
    expect((interruption.reset as PluginQuotaResetKnown).resetAt, DateTime.utc(2026, 9, 23, 15, 30));
  });

  test("weekly quota uses the original Los Angeles date rather than the UTC date", () {
    final interruption =
        map(
          text: "You've hit your weekly limit · resets 6pm (America/Los_Angeles)",
          fields: {"timestamp": "2026-11-06T01:19:19.806Z"},
        ) ??
        fail("weekly quota was not recognized");
    expect(interruption.errorMessageId, "visible-error-id");
    expect(interruption.observedAt, DateTime.parse("2026-11-06T01:19:19.806Z"));
    expect((interruption.reset as PluginQuotaResetKnown).resetAt, DateTime.utc(2026, 11, 6, 2));
  });

  test("weekly quota with an unusable reset remains an explicit unknown interruption", () {
    for (final suffix in [
      "",
      " · resets tomorrow",
      " · resets Nov 12 at 6pm (America/Los_Angeles)",
      " · resets 13pm (America/Los_Angeles)",
      " · resets 6pm (Unknown/Zone)",
    ]) {
      final interruption =
          map(text: "You've hit your weekly limit$suffix", fields: const {}) ??
          fail("weekly quota was not recognized: $suffix");
      expect(interruption.reset, isA<PluginQuotaResetUnknown>(), reason: suffix);
    }
    final stale =
        map(
          text: "You've hit your weekly limit · resets 6pm (America/Los_Angeles)",
          fields: {"timestamp": "2026-11-06T03:00:00Z"},
        ) ??
        fail("stale weekly quota was not recognized");
    expect(stale.reset, isA<PluginQuotaResetUnknown>());
  });

  test("weekly quota still requires a tagged root error with a visible identity", () {
    const text = "You've hit your weekly limit · resets 6pm (America/Los_Angeles)";
    for (final fields in [
      {"error": null},
      {"error": "billing_error"},
      {"parent_tool_use_id": "child-tool"},
      {
        "message": {
          "content": [
            {"type": "text", "text": text},
          ],
        },
      },
    ]) {
      expect(map(text: text, fields: fields), isNull);
    }
    expect(map(text: "You've hit your daily limit · resets 6pm (America/Los_Angeles)", fields: const {}), isNull);
  });

  test("whole-hour and 12-hour notation use the named zone", () {
    for (final (time, hour) in [("6pm", 15), ("12pm", 9), ("12am", 21)]) {
      final timestamp = time == "12am" ? "2026-09-22T20:00:00Z" : "2026-09-23T08:00:00Z";
      final interruption = map(
        text: "You've hit your session limit · resets $time (Europe/Sofia)",
        fields: {"timestamp": timestamp},
      );
      if (interruption == null) fail("quota interruption was not mapped");
      final reset = interruption.reset;
      // A date-less midnight already passed on the observed local date.
      if (time == "12am") {
        expect(reset, isA<PluginQuotaResetUnknown>());
      } else {
        expect((reset as PluginQuotaResetKnown).resetAt, DateTime.utc(2026, 9, 23, hour));
      }
    }
  });

  test("missing, stale, malformed and ambiguous reset times remain unknown", () {
    for (final reset in [
      "",
      " · resets 4pm (Europe/Sofia)",
      " · resets tomorrow",
      " · resets 13pm (Europe/Sofia)",
      " · resets 6:80pm (Europe/Sofia)",
      " · resets 6pm (Unknown/Zone)",
    ]) {
      expect(map(text: "You've hit your session limit$reset", fields: const {})?.reset, isA<PluginQuotaResetUnknown>());
    }
    for (final timestamp in ["2026-03-29T00:00:00Z", "2026-10-25T00:00:00Z"]) {
      expect(
        map(
          text: "You've hit your session limit · resets 3:30am (Europe/Sofia)",
          fields: {"timestamp": timestamp},
        )?.reset,
        isA<PluginQuotaResetUnknown>(),
      );
    }
  });

  test("ordinary text, subagents, billing errors and generic 429s are not quota observations", () {
    const text = "You've hit your session limit · resets 6:30pm (Europe/Sofia)";
    for (final fields in [
      {"error": null},
      {"error": "billing_error"},
      {"parent_tool_use_id": "child-tool"},
      {
        "message": {
          "id": "",
          "content": [
            {"type": "text", "text": text},
          ],
        },
      },
    ]) {
      expect(map(text: text, fields: fields), isNull);
    }
    for (final text in ["429 Too many requests", "Connection reset by peer", "Please reset your API key"]) {
      expect(map(text: text, fields: const {}), isNull);
    }
  });
}
