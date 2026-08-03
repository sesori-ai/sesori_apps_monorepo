import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/repositories/codex_tool_correlation_tracker.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_rollout_tool_mapper.dart";
import "package:codex_plugin/src/repositories/models/codex_tool_projection.dart";
import "package:test/test.dart";

void main() {
  test("correlates app-server command ids with rollout calls in turn order", () {
    final tracker = CodexToolCorrelationTracker(
      rolloutToolMapper: const CodexRolloutToolMapper(
        imageAttachmentMapper: CodexImageAttachmentMapper(),
      ),
    );
    tracker
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-1", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-2", turnId: "turn-1"),
      );

    final firstStarted = tracker.correlateAppServerCommand(
      notification: _commandNotification(
        method: "item/started",
        itemId: "exec-1",
        turnId: "turn-1",
      ),
    );
    final firstCompleted = tracker.correlateAppServerCommand(
      notification: _commandNotification(
        method: "item/completed",
        itemId: "exec-1",
        turnId: "turn-1",
      ),
    );
    final secondStarted = tracker.correlateAppServerCommand(
      notification: _commandNotification(
        method: "item/started",
        itemId: "exec-2",
        turnId: "turn-1",
      ),
    );

    expect(firstStarted, isA<CodexAppServerCommandCanonical>().having((value) => value.callId, "callId", "call-1"));
    expect(firstCompleted, isA<CodexAppServerCommandCanonical>().having((value) => value.callId, "callId", "call-1"));
    expect(secondStarted, isA<CodexAppServerCommandCanonical>().having((value) => value.callId, "callId", "call-2"));

    tracker.clearThread(threadId: "thread-1");
    expect(
      tracker.correlateAppServerCommand(
        notification: _commandNotification(
          method: "item/completed",
          itemId: "exec-2",
          turnId: "turn-1",
        ),
      ),
      isA<CodexAppServerCommandNative>(),
    );
  });

  test("leaves commands native when rollout turn metadata is unavailable", () {
    final tracker = CodexToolCorrelationTracker(
      rolloutToolMapper: const CodexRolloutToolMapper(
        imageAttachmentMapper: CodexImageAttachmentMapper(),
      ),
    );
    tracker.observeRolloutLine(
      threadId: "thread-1",
      line: _shellCall(callId: "call-1", turnId: null),
    );

    expect(
      tracker.correlateAppServerCommand(
        notification: _commandNotification(
          method: "item/started",
          itemId: "exec-1",
          turnId: "turn-1",
        ),
      ),
      isA<CodexAppServerCommandNative>(),
    );
  });

  test("excludes raw-only custom exec calls from command correlation", () {
    final tracker = CodexToolCorrelationTracker(
      rolloutToolMapper: const CodexRolloutToolMapper(
        imageAttachmentMapper: CodexImageAttachmentMapper(),
      ),
    );
    tracker
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-raw", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-1", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-2", turnId: "turn-1"),
      );

    final firstStarted = tracker.correlateAppServerCommand(
      notification: _commandNotification(
        method: "item/started",
        itemId: "exec-1",
        turnId: "turn-1",
      ),
    );
    final secondStarted = tracker.correlateAppServerCommand(
      notification: _commandNotification(
        method: "item/started",
        itemId: "exec-2",
        turnId: "turn-1",
      ),
    );

    expect(firstStarted, isA<CodexAppServerCommandCanonical>().having((value) => value.callId, "callId", "call-1"));
    expect(secondStarted, isA<CodexAppServerCommandCanonical>().having((value) => value.callId, "callId", "call-2"));
  });

  test("suppresses wait calls and projects their result onto the shell call", () {
    final tracker = CodexToolCorrelationTracker(
      rolloutToolMapper: const CodexRolloutToolMapper(
        imageAttachmentMapper: CodexImageAttachmentMapper(),
      ),
    );

    expect(
      tracker.observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-shell", turnId: "turn-1"),
      ),
      isA<CodexRolloutToolPassthrough>(),
    );
    expect(
      tracker.observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-shell",
          output: "Script running with cell ID 7\nOutput:\n",
        ),
      ),
      isA<CodexRolloutToolPassthrough>(),
    );
    expect(
      tracker.observeRolloutLine(
        threadId: "thread-1",
        line: _waitCall(
          callId: "call-wait",
          turnId: "turn-1",
          cellId: "7",
        ),
      ),
      isA<CodexRolloutToolSuppressed>(),
    );

    final completed = tracker.observeRolloutLine(
      threadId: "thread-1",
      line: _toolOutput(
        callId: "call-wait",
        output: "aborted by user after 1.0s",
      ),
    );
    expect(
      completed,
      isA<CodexRolloutToolCanonical>().having(
        (value) => value.callId,
        "callId",
        "call-shell",
      ),
    );
  });

  test("correlates waits chronologically without turn metadata", () {
    final tracker = CodexToolCorrelationTracker(
      rolloutToolMapper: const CodexRolloutToolMapper(
        imageAttachmentMapper: CodexImageAttachmentMapper(),
      ),
    );

    tracker
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-shell", turnId: null),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-shell",
          output: "Script running with cell ID 7\nOutput:\nearly output\n",
        ),
      );
    expect(
      tracker.observeRolloutLine(
        threadId: "thread-1",
        line: _waitCall(
          callId: "call-wait",
          turnId: null,
          cellId: "7",
        ),
      ),
      isA<CodexRolloutToolSuppressed>(),
    );

    expect(
      tracker.observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-wait",
          output: "Script completed with exit code 0\nFinal output:\nlate output\n",
        ),
      ),
      isA<CodexRolloutToolCanonical>().having(
        (value) => value.callId,
        "callId",
        "call-shell",
      ),
    );
  });

  test("recognizes executor control markers only at the envelope start", () {
    const mapper = CodexRolloutToolMapper(
      imageAttachmentMapper: CodexImageAttachmentMapper(),
    );

    final completedWithRunningStdout = mapper.mapResult(
      (_toolOutput(
                callId: "call-running-text",
                output:
                    "Script completed with exit code 0\n"
                    "Final output:\n"
                    "Script running with cell ID 7\n",
              )
              as CodexRolloutResponseItemLineDto)
          .payload,
    );
    final completedWithAbortedStdout = mapper.mapResult(
      (_toolOutput(
                callId: "call-aborted-text",
                output:
                    "Script completed with exit code 0\n"
                    "Final output:\n"
                    "aborted by user after 1.0s\n",
              )
              as CodexRolloutResponseItemLineDto)
          .payload,
    );

    expect(completedWithRunningStdout, isA<CodexRolloutToolCompletedResult>());
    expect(completedWithAbortedStdout, isA<CodexRolloutToolCompletedResult>());
  });
}

CodexRolloutLineDto _shellCall({
  required String callId,
  required String? turnId,
}) {
  return CodexRolloutLineDto.fromJson({
    "type": "response_item",
    "payload": {
      "type": "function_call",
      "call_id": callId,
      "name": "exec_command",
      "arguments": '{"cmd":"pwd"}',
      if (turnId != null)
        "internal_chat_message_metadata_passthrough": {
          "turn_id": turnId,
        },
    },
  });
}

CodexRolloutLineDto _rawExecCall({
  required String callId,
  required String turnId,
}) {
  return CodexRolloutLineDto.fromJson({
    "type": "response_item",
    "payload": {
      "type": "custom_tool_call",
      "call_id": callId,
      "name": "exec",
      "input": "await tools.exec_command({cmd: 'pwd'});",
      "internal_chat_message_metadata_passthrough": {
        "turn_id": turnId,
      },
    },
  });
}

CodexRolloutLineDto _waitCall({
  required String callId,
  required String? turnId,
  required String cellId,
}) {
  return CodexRolloutLineDto.fromJson({
    "type": "response_item",
    "payload": {
      "type": "function_call",
      "call_id": callId,
      "name": "wait",
      "arguments": '{"cell_id":"$cellId"}',
      if (turnId != null)
        "internal_chat_message_metadata_passthrough": {
          "turn_id": turnId,
        },
    },
  });
}

CodexRolloutLineDto _toolOutput({
  required String callId,
  required String output,
}) {
  return CodexRolloutLineDto.fromJson({
    "type": "response_item",
    "payload": {
      "type": "function_call_output",
      "call_id": callId,
      "output": output,
    },
  });
}

CodexServerNotification _commandNotification({
  required String method,
  required String itemId,
  required String turnId,
}) {
  return CodexServerNotification(
    method: method,
    params: {
      "threadId": "thread-1",
      "turnId": turnId,
      "item": {
        "type": "commandExecution",
        "id": itemId,
      },
    },
  );
}
