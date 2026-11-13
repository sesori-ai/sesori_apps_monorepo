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
    // fresh UUID message id (acp_adapter/server.py::_finish_turn); for a failed
    // turn it then fails `session/prompt` with `admitted_turn_failed`.
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
            .having((error) => error.errorName, "errorName", "hermes_failed_turn")
            .having((error) => error.errorMessage, "errorMessage", _providerTimeoutPlain),
      );
      expect(events.whereType<BridgeSseMessagePartUpdated>(), isEmpty);
      expect(events.whereType<BridgeSseMessagePartDelta>(), isEmpty);
    });

    test("every family of Hermes failure copy is a notice", () {
      for (final MapEntry(key: family, value: notice) in failureNotices.entries) {
        expect(mapper.classifyHaltNotice(text: notice)?.errorName, "hermes_failed_turn", reason: family);
      }
    });

    // An error notice shows as plain text, so the Markdown code spans Hermes
    // writes in its copy would read as literal backticks.
    test("every family of Hermes failure copy shows its code spans without backticks", () {
      for (final MapEntry(key: family, value: notice) in failureNotices.entries) {
        mapper.beginTurn(sessionId: "s1", messageId: null);
        final events = mapper.map(finalResponse(text: notice));

        expect(
          events.whereType<BridgeSseMessageUpdated>().single.info,
          isA<PluginMessageError>().having(
            (error) => error.errorMessage,
            "errorMessage",
            allOf(isNot(contains("`")), notice.replaceAll("`", "")),
          ),
          reason: family,
        );
      }
    });

    // The bridge keeps one notice per failed turn and adds a replayed wording
    // only when its error name differs: the generic saved row is a stand-in
    // for the live reason, the rows warning that actions may already have run
    // add a warning of their own.
    test("Hermes's generic saved row and its content-refused row are the same kind of notice as the live reason", () {
      for (final row in [failedTurnBoundary, contentRefusedRow]) {
        expect(mapper.classifyHaltNotice(text: row)?.errorName, "hermes_failed_turn", reason: row);
      }
    });

    // With part of the reply already streamed, Hermes sends no explanation and
    // only fails the prompt.
    test("a failed prompt with no explanation shows Hermes's saved-row wording as the same kind of notice", () {
      expect(
        mapper.mapPromptError(sessionId: "s1", message: "admitted_turn_failed").info,
        isA<PluginMessageError>()
            .having((error) => error.errorName, "errorName", "hermes_failed_turn")
            .having((error) => error.errorMessage, "errorMessage", failedTurnBoundary),
      );
    });

    test("any other prompt failure keeps the shared notice", () {
      expect(
        mapper.mapPromptError(sessionId: "s1", message: "Connection closed").info,
        isA<PluginMessageError>()
            .having((error) => error.errorName, "errorName", "ACP prompt failed")
            .having((error) => error.errorMessage, "errorMessage", "Connection closed"),
      );
    });

    test("Hermes's partial-turn and interrupted-automation rows are notices of their own kind", () {
      for (final row in [partialFailedTurnBoundary, automationInterruptedBoundary]) {
        expect(mapper.classifyHaltNotice(text: row)?.errorName, "hermes_partial_turn", reason: row);
      }
    });

    // Hermes 0.23.1 closes a live reason with its generic saved row, which
    // the history store drops on reload as the same kind of notice.
    test("a live notice drops the generic saved row Hermes appends after the reason", () {
      final events = mapper.map(finalResponse(text: "$providerTimeoutNotice\n\n$failedTurnBoundary"));

      expect(
        events.whereType<BridgeSseMessageUpdated>().single.info,
        isA<PluginMessageError>().having((error) => error.errorMessage, "errorMessage", _providerTimeoutPlain),
      );
    });

    test("a live notice keeps the generic saved row when it is the only text", () {
      final events = mapper.map(finalResponse(text: failedTurnBoundary));

      expect(
        events.whereType<BridgeSseMessageUpdated>().single.info,
        isA<PluginMessageError>().having((error) => error.errorMessage, "errorMessage", failedTurnBoundary),
      );
    });

    test("a live notice keeps an appended partial-turn warning", () {
      final events = mapper.map(finalResponse(text: "$providerTimeoutNotice\n\n$partialFailedTurnBoundary"));

      expect(
        events.whereType<BridgeSseMessageUpdated>().single.info,
        isA<PluginMessageError>().having(
          (error) => error.errorMessage,
          "errorMessage",
          "$_providerTimeoutPlain\n\n$partialFailedTurnBoundary",
        ),
      );
    });

    test("a reply that only ends with Hermes's launch-credentials details line stays a reply", () {
      for (final reply in const {
        "plain text first": "Your key was rejected earlier.\n\nDetails: launch_credentials_unavailable (OPENROUTER_API_KEY: unavailable)",
        "a paragraph between":
            "⚠️ Hermes said this before (OPENROUTER_API_KEY: unavailable).\n\nThen I retried.\n\n"
            "Details: launch_credentials_unavailable (OPENROUTER_API_KEY: unavailable)",
        "another key named":
            "⚠️ Hermes refused the key (ANTHROPIC_API_KEY: unavailable).\n\n"
            "Details: launch_credentials_unavailable (OPENROUTER_API_KEY: unavailable)",
      }.values) {
        expect(mapper.classifyHaltNotice(text: reply), isNull, reason: reply);
      }
    });

    // Every assistant text starting with "⚠️ " reaches this check, so a long
    // first line full of parentheses must not take seconds to classify.
    test("a long warning reply with many parentheses is classified in one scan", () {
      final reply = "⚠️ ${List.filled(2000, "word (note) more").join(" ")}\n\nA second paragraph.";
      final stopwatch = Stopwatch()..start();

      expect(mapper.classifyHaltNotice(text: reply), isNull);
      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 200)));
    });

    test("a no-reply explanation for an exit that does not fail the turn stays a reply", () {
      for (final text in advisoryNoReplyTexts.values) {
        expect(mapper.classifyHaltNotice(text: text), isNull, reason: text);
      }
    });

    test("Hermes's live-only queue acknowledgement is dropped", () {
      const acknowledgement = AcpNotification(
        method: "session/update",
        params: {
          "sessionId": "s1",
          "update": {
            "sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": "Queued for the next turn. (1 queued)"},
          },
        },
      );

      expect(mapper.map(acknowledgement), isEmpty);
      expect(mapper.map(finalResponse(text: "Queued for the next turn. (1 queued)")), isNotEmpty);
      expect(
        mapper.map(finalResponse(text: "Queued for the next turn. (1 queued) Then I will run it.")),
        isNotEmpty,
      );
    });

    test("a real reply stays assistant text", () {
      final events = mapper.map(finalResponse(text: "The build passes now."));

      expect(events.whereType<BridgeSseMessageUpdated>().single.info, isA<PluginMessageAssistant>());
      expect(events.whereType<BridgeSseMessagePartDelta>().single.delta, "The build passes now.");
    });

    test("a reply that quotes a notice stays assistant text", () {
      for (final notice in [
        ...failureNotices.values,
        failedTurnBoundary,
        partialFailedTurnBoundary,
        automationInterruptedBoundary,
        contentRefusedRow,
      ]) {
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

/// [providerTimeoutNotice] as shown: its `hermes fallback add` code span unwrapped.
const String _providerTimeoutPlain =
    "custom didn't respond in time on any of 3 attempts — it looks temporarily unavailable. "
    "Wait a minute and send /retry, or switch models with /model. To avoid this in future, "
    "add a backup provider with hermes fallback add.\n\nProvider said: Connection error.";
