import "package:pi_plugin/src/api/models/pi_event.dart";
import "package:pi_plugin/src/repositories/mappers/pi_history_mapper.dart";
import "package:pi_plugin/src/repositories/mappers/pi_quota_interruption_mapper.dart";
import "package:pi_plugin/src/services/pi_event_dispatcher.dart";
import "package:pi_plugin/src/trackers/pi_message_identity_tracker.dart";
import "package:pi_plugin/src/trackers/pi_tool_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  final history = PiHistoryMapper(pluginId: "pi");
  final mapper = PiQuotaInterruptionMapper(historyMapper: history);
  final observedAt = DateTime.utc(2026, 9, 16, 19, 34, 27);

  PluginQuotaInterruption? map({required String text, required Map<String, Object?> fields}) {
    final event = PiEvent.parse(
      type: "message_end",
      json: {
        "type": "message_end",
        "message": {
          "role": "assistant",
          "provider": "openai-codex",
          "stopReason": "error",
          "content": <Object?>[],
          "timestamp": observedAt.millisecondsSinceEpoch,
          "errorMessage": text,
          ...fields,
        },
      },
    ) as PiMessageEndEvent;
    final dispatcher = PiEventDispatcher(
      historyMapper: history,
      identityTracker: PiMessageIdentityTracker(pluginId: "pi"),
      toolTracker: PiToolTracker(),
    );
    final visible = dispatcher
        .map(sessionId: "session", event: event)
        .whereType<BridgeSseMessageUpdated>()
        .firstOrNull
        ?.info;
    final result = mapper.map(
      event: event,
      mappedMessage: visible,
      observedAt: observedAt.add(const Duration(days: 1)),
    );
    if (result != null) expect(result.errorMessageId, visible!.id);
    return result;
  }

  test("observed multi-day duration is anchored to the error, not later delivery", () {
    final result = map(
      text: "You have hit your ChatGPT usage limit (pro plan). Try again in ~5918 min.",
      fields: const {},
    )!;
    expect(result.observedAt, observedAt);
    expect((result.reset as PluginQuotaResetKnown).resetAt, observedAt.add(const Duration(minutes: 5918)));
  });

  test("quota without a usable original timestamp or reset remains visible but unschedulable", () {
    for (final text in [
      "Codex error: The usage limit has been reached",
      "You have hit your ChatGPT usage limit.",
      "You have hit your ChatGPT usage limit. Try again in ~0 min.",
      "You have hit your ChatGPT usage limit. Try again in ~-5 min.",
      "You have hit your ChatGPT usage limit. Try again in ~999999999999999 min.",
    ]) {
      expect(map(text: text, fields: const {})!.reset, isA<PluginQuotaResetUnknown>());
    }
    for (final timestamp in [null, 9000000000000000]) {
      expect(
        map(
          text: "You have hit your ChatGPT usage limit. Try again in ~60 min.",
          fields: {"timestamp": timestamp},
        )!.reset,
        isA<PluginQuotaResetUnknown>(),
      );
    }
  });

  test("wrong provider, successful or aborted responses and generic failures do not qualify", () {
    for (final fields in [
      {"provider": "anthropic"},
      {"stopReason": "stop"},
      {"stopReason": "aborted"},
    ]) {
      expect(map(text: "You have hit your ChatGPT usage limit. Try again in ~60 min.", fields: fields), isNull);
    }
    for (final text in [
      "Connection reset by peer",
      "429 Too many requests",
      "Authentication failed",
      "Insufficient credits",
    ]) {
      expect(map(text: text, fields: const {}), isNull);
    }
  });
}
