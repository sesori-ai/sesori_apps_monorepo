import "package:acp_plugin/acp_plugin.dart";
import "package:hermes_plugin/src/hermes_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// The final response Hermes streamed when its model provider stayed
/// unreachable through every retry (reported 2026-11-09 on Hermes 0.21.5,
/// whose `agent/turn_failure_copy.py::exhausted_copy` writes this shape).
const String providerTimeoutNotice =
    "custom didn't respond in time on any of 3 attempts — it looks temporarily unavailable. "
    "Wait a minute and send /retry, or switch models with /model. To avoid this in future, "
    "add a backup provider with `hermes fallback add`.\n\nProvider said: Connection error.";

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
            .having((error) => error.errorName, "errorName", "hermes_provider_failure")
            .having((error) => error.errorMessage, "errorMessage", providerTimeoutNotice),
      );
      expect(events.whereType<BridgeSseMessagePartUpdated>(), isEmpty);
      expect(events.whereType<BridgeSseMessagePartDelta>(), isEmpty);
    });

    test("the other retry-exhausted leads and the usage-limit wording are notices too", () {
      const rateLimited =
          "OpenRouter rate-limited every one of 4 attempts — it looks temporarily unavailable. "
          "Wait a minute and send /retry, or switch models with /model. To avoid this in future, "
          "add a backup provider with `hermes fallback add`.\n\nProvider said: HTTP 429";
      const usageLimited =
          "Nous Portal returned a server error on all 3 attempts — its usage limit resets in ~3h. "
          "Send /retry after that, or switch models with /model. To avoid this in future, "
          "add a backup provider with `hermes fallback add`.\n\nProvider said: HTTP 503";
      for (final notice in [rateLimited, usageLimited]) {
        expect(mapper.classifyHaltNotice(text: notice), isNotNull, reason: notice);
      }
    });

    test("a real reply stays assistant text", () {
      final events = mapper.map(finalResponse(text: "The build passes now."));

      expect(events.whereType<BridgeSseMessageUpdated>().single.info, isA<PluginMessageAssistant>());
      expect(events.whereType<BridgeSseMessagePartDelta>().single.delta, "The build passes now.");
    });

    test("a reply that quotes the notice stays assistant text", () {
      const quoted = "Hermes printed this earlier:\n\n$providerTimeoutNotice\n\nI switched to a backup provider.";

      expect(mapper.classifyHaltNotice(text: quoted), isNull);
      expect(
        mapper.map(finalResponse(text: quoted)).whereType<BridgeSseMessageUpdated>().single.info,
        isA<PluginMessageAssistant>(),
      );
    });

    test("a reply that keeps the lead but drops Hermes's tail stays assistant text", () {
      expect(
        mapper.classifyHaltNotice(text: "custom didn't respond in time on any of 3 attempts — try again later."),
        isNull,
      );
    });
  });
}
