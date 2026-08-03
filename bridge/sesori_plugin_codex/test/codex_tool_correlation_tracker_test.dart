import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/repositories/codex_tool_correlation_tracker.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_rollout_tool_mapper.dart";
import "package:codex_plugin/src/repositories/models/codex_command_projection.dart";
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
      _commandNotification(
        method: "item/started",
        itemId: "exec-1",
        turnId: "turn-1",
      ),
    );
    final firstCompleted = tracker.correlateAppServerCommand(
      _commandNotification(
        method: "item/completed",
        itemId: "exec-1",
        turnId: "turn-1",
      ),
    );
    final secondStarted = tracker.correlateAppServerCommand(
      _commandNotification(
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
        _commandNotification(
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
        _commandNotification(
          method: "item/started",
          itemId: "exec-1",
          turnId: "turn-1",
        ),
      ),
      isA<CodexAppServerCommandNative>(),
    );
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
