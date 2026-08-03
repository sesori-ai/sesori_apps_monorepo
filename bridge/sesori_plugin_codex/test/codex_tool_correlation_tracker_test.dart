import "package:codex_plugin/src/api/models/codex_command_execution_dto.dart";
import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/repositories/codex_tool_correlation_tracker.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_rollout_tool_mapper.dart";
import "package:codex_plugin/src/repositories/models/codex_tool_projection.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
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
      command: _commandEvent(
        method: "item/started",
        itemId: "exec-1",
        turnId: "turn-1",
      ),
    );
    final firstCompleted = tracker.correlateAppServerCommand(
      command: _commandEvent(
        method: "item/completed",
        itemId: "exec-1",
        turnId: "turn-1",
      ),
    );
    final secondStarted = tracker.correlateAppServerCommand(
      command: _commandEvent(
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
        command: _commandEvent(
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
        command: _commandEvent(
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
      command: _commandEvent(
        method: "item/started",
        itemId: "exec-1",
        turnId: "turn-1",
      ),
    );
    final secondStarted = tracker.correlateAppServerCommand(
      command: _commandEvent(
        method: "item/started",
        itemId: "exec-2",
        turnId: "turn-1",
      ),
    );

    expect(firstStarted, isA<CodexAppServerCommandCanonical>().having((value) => value.callId, "callId", "call-1"));
    expect(secondStarted, isA<CodexAppServerCommandCanonical>().having((value) => value.callId, "callId", "call-2"));
  });

  test("suppresses generated image wrappers from rollout tools", () {
    const mapper = CodexRolloutToolMapper(
      imageAttachmentMapper: CodexImageAttachmentMapper(),
    );
    final line =
        CodexRolloutLineDto.fromJson({
              "type": "response_item",
              "payload": {
                "type": "custom_tool_call",
                "call_id": "call-image-wrapper",
                "name": "exec",
                "input": "await tools.image_gen__generate({prompt: 'private'});",
              },
            })
            as CodexRolloutResponseItemLineDto;

    expect(
      mapper.internalCallId(payload: line.payload),
      "call-image-wrapper",
    );
  });

  test("structured command failure remains canonical across rollout replay", () {
    final tracker = CodexToolCorrelationTracker(
      rolloutToolMapper: const CodexRolloutToolMapper(
        imageAttachmentMapper: CodexImageAttachmentMapper(),
      ),
    );
    tracker.observeRolloutLine(
      threadId: "thread-1",
      line: _shellCall(callId: "call-1", turnId: "turn-1"),
    );

    final commandProjection = tracker.correlateAppServerCommand(
      command: const CodexCommandExecutionEventDto(
        lifecycle: CodexCommandExecutionLifecycle.completed,
        threadId: "thread-1",
        turnId: "turn-1",
        itemId: "exec-1",
        status: CodexCommandExecutionStatus.failed,
        exitCode: 1,
      ),
    );
    final rolloutProjection = tracker.observeRolloutLine(
      threadId: "thread-1",
      line: _toolOutput(callId: "call-1", output: "opaque output"),
    );

    expect(
      commandProjection,
      isA<CodexAppServerCommandCanonicalError>()
          .having((value) => value.sessionId, "sessionId", "thread-1")
          .having((value) => value.callId, "callId", "call-1"),
    );
    expect(
      rolloutProjection,
      isA<CodexRolloutToolCanonicalError>().having(
        (value) => value.callId,
        "callId",
        "call-1",
      ),
    );
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

  test("retires a waited cell when a chained wait replaces it", () {
    final tracker = CodexToolCorrelationTracker(
      rolloutToolMapper: const CodexRolloutToolMapper(
        imageAttachmentMapper: CodexImageAttachmentMapper(),
      ),
    );
    tracker
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-exec", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-exec",
          output: "Script running with cell ID 7\nOutput:\n",
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _waitCall(
          callId: "call-wait-7",
          turnId: "turn-1",
          cellId: "7",
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-wait-7",
          output: "Script running with cell ID 8\nOutput:\n",
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _waitCall(
          callId: "call-wait-8",
          turnId: "turn-1",
          cellId: "8",
        ),
      );

    expect(
      tracker.observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-wait-8",
          output: "Script completed with exit code 0\nFinal output:\ndone\n",
        ),
      ),
      isA<CodexRolloutToolCanonical>(),
    );
  });

  test("canonical terminal output clears its own running cells", () {
    final tracker = CodexToolCorrelationTracker(
      rolloutToolMapper: const CodexRolloutToolMapper(
        imageAttachmentMapper: CodexImageAttachmentMapper(),
      ),
    );
    tracker
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-exec", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-exec",
          output: "Script running with cell ID 7\nOutput:\n",
        ),
      );

    expect(
      tracker.observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-exec",
          output: "Script completed with exit code 0\nFinal output:\ndone\n",
        ),
      ),
      isA<CodexRolloutToolPassthrough>(),
    );
  });

  test("correlates every running cell from a composed exec", () {
    final tracker = CodexToolCorrelationTracker(
      rolloutToolMapper: const CodexRolloutToolMapper(
        imageAttachmentMapper: CodexImageAttachmentMapper(),
      ),
    );

    tracker
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-exec", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolContentOutput(
          callId: "call-exec",
          outputs: const [
            "Script running with cell ID 7\nOutput:\nfirst\n",
            "Script running with cell ID 8\nOutput:\nsecond\n",
          ],
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _waitCall(
          callId: "call-wait-8",
          turnId: "turn-1",
          cellId: "8",
        ),
      );

    expect(
      tracker.observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-wait-8",
          output: "Script completed with exit code 0\nFinal output:\ndone\n",
        ),
      ),
      isA<CodexRolloutToolCanonicalRunning>().having(
        (value) => value.callId,
        "callId",
        "call-exec",
      ),
    );

    tracker.observeRolloutLine(
      threadId: "thread-1",
      line: _waitCall(
        callId: "call-wait-7",
        turnId: "turn-1",
        cellId: "7",
      ),
    );
    expect(
      tracker.observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-wait-7",
          output: "Script completed with exit code 0\nFinal output:\ndone\n",
        ),
      ),
      isA<CodexRolloutToolCanonical>(),
    );
  });

  test("merged output reserves space for the current terminal result", () {
    final merged =
        const CodexRolloutToolCompletedResult(
          callId: "call-wait",
          output: "terminal-result",
          attachments: [],
        ).withPreviousResult(
          previous: CodexRolloutToolRunningResult(
            callId: "call-exec",
            output: "x" * maxToolOutputLength,
            attachments: const [],
            cellIds: const ["7"],
          ),
        );

    expect(merged.output?.runes, hasLength(maxToolOutputLength));
    expect(merged.output, endsWith("terminal-result"));
  });

  test("merged composed results preserve error precedence", () {
    final merged =
        const CodexRolloutToolCompletedResult(
          callId: "call-wait-success",
          output: "success-output",
          attachments: [],
        ).withPreviousResult(
          previous: const CodexRolloutToolErrorResult(
            callId: "call-wait-failed",
            output: "failed-output",
            attachments: [],
          ),
        );

    expect(merged, isA<CodexRolloutToolErrorResult>());
    expect(merged.output, contains("failed-output"));
    expect(merged.output, contains("success-output"));
  });

  test("composed output preserves failures alongside running cells", () {
    const mapper = CodexRolloutToolMapper(
      imageAttachmentMapper: CodexImageAttachmentMapper(),
    );

    final result = mapper.mapResult(
      (_toolContentOutput(
                callId: "call-exec",
                outputs: const [
                  "Script running with cell ID 7\nOutput:\nstill running\n",
                  "Process exited with code 1\nFinal output:\nfailed\n",
                ],
              )
              as CodexRolloutResponseItemLineDto)
          .payload,
    );

    expect(result, isA<CodexRolloutToolErrorWithRunningCellsResult>());
    expect(
      (result! as CodexRolloutToolErrorWithRunningCellsResult).cellIds,
      ["7"],
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

CodexRolloutLineDto _toolContentOutput({
  required String callId,
  required List<String> outputs,
}) {
  return CodexRolloutLineDto.fromJson({
    "type": "response_item",
    "payload": {
      "type": "custom_tool_call_output",
      "call_id": callId,
      "output": [
        for (final output in outputs)
          {
            "type": "output_text",
            "text": output,
          },
      ],
    },
  });
}

CodexCommandExecutionEventDto _commandEvent({
  required String method,
  required String itemId,
  required String turnId,
}) {
  return CodexCommandExecutionEventDto(
    lifecycle: method == "item/started"
        ? CodexCommandExecutionLifecycle.started
        : CodexCommandExecutionLifecycle.completed,
    threadId: "thread-1",
    turnId: turnId,
    itemId: itemId,
    status: method == "item/started" ? CodexCommandExecutionStatus.inProgress : CodexCommandExecutionStatus.completed,
    exitCode: null,
  );
}
