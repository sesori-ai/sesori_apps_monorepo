import "package:pi_plugin/pi_plugin.dart";
import "package:pi_plugin/pi_testing.dart";
import "package:test/test.dart";

PiRpcFrame parseFrame(Map<String, Object?> json) => PiRpcFrame.parse(json: json);

PiEvent parseEvent(Map<String, Object?> json) => (parseFrame(json) as PiEventFrame).event;

PiExtensionUiRequest parseUiRequest(Map<String, Object?> json) => (parseFrame(json) as PiExtensionUiFrame).request;

PiAssistantDelta parseDelta(Map<String, Object?> delta) =>
    (parseEvent({"type": "message_update", "assistantMessageEvent": delta}) as PiMessageUpdateEvent).delta;

void main() {
  group("responses", () {
    test("routes a success response with its data", () {
      final frame = parseFrame(
        piSuccessResponseFixture(id: "sesori-1", command: "get_state", data: {"sessionId": "s1"}),
      );

      expect(frame, isA<PiSuccessResponseFrame>());
      final response = frame as PiSuccessResponseFrame;
      expect(response.id, "sesori-1");
      expect(response.command, PiRpcCommand.getState);
      expect(response.data["sessionId"], "s1");
    });

    test("routes a failure response and keeps Pi's untyped error", () {
      final frame = parseFrame(
        piFailureResponseFixture(id: "sesori-2", command: "prompt", error: "No model selected"),
      );

      final response = frame as PiFailureResponseFrame;
      expect(response.error, "No model selected");
      expect(response.command, PiRpcCommand.prompt);
    });

    test("routes a parse failure that carries no request id", () {
      // Pi answers its own parse failures with `command: parse` and no id, so a
      // response frame must stay valid without one.
      final frame = parseFrame({
        "type": "response",
        "command": "parse",
        "success": false,
        "error": "Failed to parse command",
      });

      final response = frame as PiFailureResponseFrame;
      expect(response.id, isNull);
      expect(response.command, isNull);
      expect(response.rawCommand, "parse");
    });

    test("treats a missing success flag as a failure rather than an acceptance", () {
      expect(parseFrame({"type": "response", "command": "abort"}), isA<PiFailureResponseFrame>());
    });
  });

  group("events", () {
    test("routes every known top-level event type", () {
      final routed = {
        for (final type in [
          "agent_start",
          "agent_end",
          "agent_settled",
          "turn_start",
          "turn_end",
          "message_start",
          "message_update",
          "message_end",
          "tool_execution_start",
          "tool_execution_update",
          "tool_execution_end",
          "bash_execution_update",
          "queue_update",
          "compaction_start",
          "compaction_end",
          "entry_appended",
          "session_info_changed",
          "thinking_level_changed",
          "auto_retry_start",
          "auto_retry_end",
          "summarization_retry_scheduled",
          "summarization_retry_attempt_start",
          "summarization_retry_finished",
          "extension_error",
        ])
          type: parseEvent(piEventFixture(type: type, fields: const {})),
      };

      // None may fall through to the unknown fallback: an event that silently
      // became anonymous data would be invisible in later steps.
      expect(routed.values.whereType<PiUnknownEvent>(), isEmpty);
      expect(routed.values.map((event) => event.runtimeType).toSet(), hasLength(routed.length));
    });

    test("keeps an unmodelled event type instead of dropping it", () {
      final event = parseEvent(piEventFixture(type: "future_event", fields: {"a": 1}));

      expect((event as PiUnknownEvent).type, "future_event");
      expect(event.raw["a"], 1);
    });

    test("types the scalars Sesori decides on", () {
      final settled = parseEvent(piEventFixture(type: "agent_end", fields: {"willRetry": true}));
      final compaction = parseEvent(piEventFixture(type: "compaction_start", fields: {"reason": "overflow"}));
      final thinking = parseEvent(piEventFixture(type: "thinking_level_changed", fields: {"level": "xhigh"}));

      expect((settled as PiAgentEndEvent).willRetry, isTrue);
      expect((compaction as PiCompactionStartEvent).reason, PiCompactionReason.overflow);
      expect((thinking as PiThinkingLevelChangedEvent).level, PiThinkingLevel.xhigh);
    });

    test("models summarization source and reason as valid variants", () {
      final branchSummary = parseEvent(
        piEventFixture(type: "summarization_retry_attempt_start", fields: {"source": "branchSummary"}),
      );
      final compaction = parseEvent(
        piEventFixture(
          type: "summarization_retry_attempt_start",
          fields: {"source": "compaction", "reason": "overflow"},
        ),
      );
      final unknown = parseEvent(
        piEventFixture(type: "summarization_retry_attempt_start", fields: {"source": "future"}),
      );

      expect(
        (branchSummary as PiSummarizationRetryAttemptStartEvent).source,
        isA<PiBranchSummarySource>(),
      );
      expect(
        ((compaction as PiSummarizationRetryAttemptStartEvent).source as PiCompactionSummarizationSource).reason,
        PiCompactionReason.overflow,
      );
      expect(
        (unknown as PiSummarizationRetryAttemptStartEvent).source,
        isA<PiUnknownSummarizationSource>(),
      );
    });

    test("reports a cleared session name as null rather than an empty string", () {
      final cleared = parseEvent(piEventFixture(type: "session_info_changed", fields: const {}));
      final named = parseEvent(piEventFixture(type: "session_info_changed", fields: {"name": "Rename"}));

      expect((cleared as PiSessionInfoChangedEvent).name, isNull);
      expect((named as PiSessionInfoChangedEvent).name, "Rename");
    });

    test("survives an event whose fields have unexpected types", () {
      final event = parseEvent(
        piEventFixture(type: "tool_execution_end", fields: {"toolCallId": 7, "isError": "yes"}),
      );

      final end = event as PiToolExecutionEndEvent;
      expect(end.toolCallId, isNull);
      expect(end.isError, isFalse);
    });

    test("degrades non-finite numeric fields instead of throwing", () {
      final event = parseEvent(
        piEventFixture(
          type: "auto_retry_start",
          fields: {"attempt": double.infinity, "maxAttempts": double.nan},
        ),
      );

      expect((event as PiAutoRetryStartEvent).attempt, isNull);
      expect(event.maxAttempts, isNull);
    });

    test("keeps queue depth without modelling the queued prompt text", () {
      final event = parseEvent(
        piEventFixture(
          type: "queue_update",
          fields: {
            "steering": ["secret prompt"],
            "followUp": <Object?>[],
          },
        ),
      );

      final queue = event as PiQueueUpdateEvent;
      expect(queue.steeringCount, 1);
      expect(queue.followUpCount, 0);
    });

    test("retains cumulative tool progress and the terminal result", () {
      final update = parseEvent(
        piEventFixture(
          type: "tool_execution_update",
          fields: {
            "toolCallId": "call-1",
            "partialResult": {"content": "partial"},
          },
        ),
      );
      final end = parseEvent(
        piEventFixture(
          type: "tool_execution_end",
          fields: {
            "toolCallId": "call-1",
            "result": {"content": "complete"},
          },
        ),
      );

      expect((update as PiToolExecutionUpdateEvent).partialResult["content"], "partial");
      expect((end as PiToolExecutionEndEvent).result["content"], "complete");
    });
  });

  group("assistant deltas", () {
    test("routes every known delta type", () {
      final routed = [
        for (final type in [
          "start",
          "text_start",
          "text_delta",
          "text_end",
          "thinking_start",
          "thinking_delta",
          "thinking_end",
          "toolcall_start",
          "toolcall_delta",
          "toolcall_end",
          "done",
          "error",
        ])
          parseDelta({"type": type, "contentIndex": 0}),
      ];

      expect(routed.whereType<PiUnknownDelta>(), isEmpty);
      expect(routed.map((delta) => delta.runtimeType).toSet(), hasLength(routed.length));
    });

    test("carries tool-call identity at toolcall_start", () {
      final delta = parseDelta({
        "type": "toolcall_start",
        "contentIndex": 2,
        "id": "call-1",
        "toolName": "bash",
      });

      final start = delta as PiToolCallStartDelta;
      expect(start.contentIndex, 2);
      expect(start.id, "call-1");
      expect(start.toolName, "bash");
    });

    test("keeps the legacy toolcall_start shape available for the compatibility fallback", () {
      final delta = parseDelta({
        "type": "toolcall_start",
        "contentIndex": 2,
      });

      final start = delta as PiToolCallStartDelta;
      expect(start.contentIndex, 2);
      expect(start.id, isNull);
      expect(start.toolName, isNull);
    });

    test("carries the content index and the complete tool call at toolcall_end", () {
      final delta = parseDelta({
        "type": "toolcall_end",
        "contentIndex": 2,
        "toolCall": {"id": "call-1", "name": "bash", "arguments": <String, Object?>{}},
      });

      final end = delta as PiToolCallEndDelta;
      expect(end.contentIndex, 2);
      expect(end.toolCall["id"], "call-1");
      expect(end.toolCall["name"], "bash");
    });

    test("keeps an unmodelled delta type", () {
      expect((parseDelta({"type": "future_delta"}) as PiUnknownDelta).type, "future_delta");
    });

    test("types the closed assistant stop reasons", () {
      final done = parseDelta({"type": "done", "reason": "deferred"});
      final error = parseDelta({"type": "error", "reason": "aborted"});

      expect((done as PiAssistantDoneDelta).reason, PiAssistantStopReason.deferred);
      expect((error as PiAssistantErrorDelta).reason, PiAssistantStopReason.aborted);
    });
  });

  group("extension ui", () {
    test("routes each blocking dialog method", () {
      final select = parseUiRequest({
        "type": "extension_ui_request",
        "id": "d1",
        "method": "select",
        "title": "Pick",
        "options": ["a", "b"],
        "timeout": 30000,
      });
      final confirm = parseUiRequest({
        "type": "extension_ui_request",
        "id": "d2",
        "method": "confirm",
        "title": "Sure?",
        "message": "Proceed",
      });
      final input = parseUiRequest({
        "type": "extension_ui_request",
        "id": "d3",
        "method": "input",
        "title": "Name",
        "placeholder": "value",
      });
      final editor = parseUiRequest({
        "type": "extension_ui_request",
        "id": "d4",
        "method": "editor",
        "title": "Edit",
        "prefill": "text",
      });

      expect([select, confirm, input, editor], everyElement(isA<PiExtensionDialogRequest>()));
      expect((select as PiSelectDialogRequest).options, ["a", "b"]);
      expect(select.timeoutMs, 30000);
      expect((confirm as PiConfirmDialogRequest).message, "Proceed");
      expect((input as PiInputDialogRequest).placeholder, "value");
      expect((editor as PiEditorDialogRequest).prefill, "text");
    });

    test("types the closed notification type", () {
      final request = parseUiRequest({
        "type": "extension_ui_request",
        "id": "n1",
        "method": "notify",
        "message": "Warning",
        "notifyType": "warning",
      });

      expect((request as PiNotifyRequest).notifyType, PiNotificationType.warning);
    });

    test("routes each fire-and-forget decoration", () {
      final decorations = [
        for (final method in ["notify", "setStatus", "setWidget", "setTitle", "set_editor_text"])
          parseUiRequest({"type": "extension_ui_request", "id": "x", "method": method}),
      ];

      // A decoration must never be mistaken for a dialog: answering one would
      // resolve nothing, and leaving a dialog unanswered would block Pi.
      expect(decorations, everyElement(isA<PiExtensionDecorationRequest>()));
      expect(decorations.map((request) => request.runtimeType).toSet(), hasLength(decorations.length));
    });

    test("routes an unmodelled method as fire-and-forget", () {
      final request = parseUiRequest({"type": "extension_ui_request", "id": "x", "method": "future"});

      expect(request, isA<PiUnknownExtensionUiRequest>());
      expect(request, isNot(isA<PiExtensionDialogRequest>()));
    });

    test("falls back to unknown when no reply could ever be correlated", () {
      // Without an id there is no way to answer, so this is not a dialog.
      final frame = parseFrame({"type": "extension_ui_request", "method": "confirm", "title": "Sure?"});

      expect(frame, isA<PiUnknownFrame>());
    });
  });

  test("routes a frame with no type as unknown", () {
    expect((parseFrame({"data": 1}) as PiUnknownFrame).type, isNull);
  });
}
