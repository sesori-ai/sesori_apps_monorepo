import "package:acp_plugin/acp_plugin.dart";
import "package:hermes_plugin/src/hermes_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "fixtures/hermes_failure_copy_fixtures.dart";

void main() {
  group("HermesEventMapper", () {
    late HermesEventMapper mapper;

    setUp(() {
      final childSessions = AcpChildSessionTracker();
      mapper = HermesEventMapper(
        launchDirectory: "/repo",
        pluginId: "hermes",
        configurationTracker: AcpSessionConfigurationTracker()
          ..setProcessDefaults(modelId: "custom:model", providerId: "custom"),
        childSessions: childSessions,
      );
      mapper.beginTurn(sessionId: "s1", messageId: null);
    });

    // Hermes sends the final response as one `agent_message_chunk` carrying a
    // fresh UUID message id (acp_adapter/server.py::_finish_turn), then ends
    // the turn with `stopReason: end_turn`.
    AcpNotification finalResponse({required String text}) => AcpNotification(
      method: "session/update",
      params: {
        "sessionId": "s1",
        "update": {
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": text},
          "messageId": "0b7d4c2e-6a1f-4f3b-9d0e-2f5c8a1b7e44",
        },
      },
    );

    test("a provider failure becomes one error notice, not assistant text", () {
      final events = mapper.map(finalResponse(text: providerTimeoutNotice));

      final message = events.whereType<BridgeSseMessageUpdated>().single.info;
      expect(
        message,
        isA<PluginMessageError>()
            .having((error) => error.errorName, "errorName", "hermes_turn_failure")
            .having((error) => error.errorMessage, "errorMessage", providerTimeoutNotice),
      );
      expect(events.whereType<BridgeSseMessagePartUpdated>(), isEmpty);
      expect(events.whereType<BridgeSseMessagePartDelta>(), isEmpty);
    });

    test("every family of Hermes failure copy is a notice", () {
      for (final MapEntry(key: family, value: notice) in failureNotices.entries) {
        expect(mapper.classifyHaltNotice(text: notice)?.errorName, "hermes_turn_failure", reason: family);
      }
    });

    test("Hermes's saved failed-turn rows are notices", () {
      for (final row in [failedTurnBoundary, partialFailedTurnBoundary]) {
        expect(mapper.classifyHaltNotice(text: row)?.errorName, "hermes_failed_turn", reason: row);
      }
    });

    test("a real reply stays assistant text", () {
      final events = mapper.map(finalResponse(text: "The build passes now."));

      expect(events.whereType<BridgeSseMessageUpdated>().single.info, isA<PluginMessageAssistant>());
      expect(events.whereType<BridgeSseMessagePartDelta>().single.delta, "The build passes now.");
    });

    test("a reply that quotes a notice stays assistant text", () {
      for (final notice in [...failureNotices.values, failedTurnBoundary, partialFailedTurnBoundary]) {
        final quoted = "Hermes printed this earlier:\n\n$notice\n\nI switched to a backup provider.";
        expect(mapper.classifyHaltNotice(text: quoted), isNull, reason: notice);
      }
      expect(
        mapper
            .map(finalResponse(text: "Hermes printed this earlier:\n\n$providerTimeoutNotice"))
            .whereType<BridgeSseMessageUpdated>()
            .single
            .info,
        isA<PluginMessageAssistant>(),
      );
    });

    test("a reply that keeps a lead but drops Hermes's tail stays assistant text", () {
      expect(
        mapper.classifyHaltNotice(text: "custom didn't respond in time on any of 3 attempts — try again later."),
        isNull,
      );
    });

    test("a reasoning-only stop stays a reply, because it carries the model's own thoughts", () {
      expect(
        mapper.classifyHaltNotice(
          text:
              "⚠️ gpt-5 spent all of its output budget thinking and never wrote an answer. Lower its reasoning "
              "effort with `/reasoning low`, or switch to a different model with /model. Its last thoughts, "
              "which may contain the answer:\n\nThe fix is to pin the version.",
        ),
        isNull,
      );
    });
  });
}
