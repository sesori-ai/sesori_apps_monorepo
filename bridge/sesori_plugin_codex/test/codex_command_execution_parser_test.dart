import "package:codex_plugin/src/api/models/codex_command_execution_dto.dart";
import "package:codex_plugin/src/api/models/codex_correlatable_item_event_dto.dart";
import "package:codex_plugin/src/api/parsers/codex_command_execution_parser.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:test/test.dart";

void main() {
  const parser = CodexCommandExecutionParser();

  test("parses completed command failure evidence into typed state", () {
    final event = parser.parse(
      notification: const CodexServerNotification(
        method: "item/completed",
        params: {
          "threadId": "thread-1",
          "turnId": "turn-1",
          "item": {
            "type": "commandExecution",
            "id": "exec-1",
            "command": "printf marker",
            "aggregatedOutput": "marker\n",
            "status": "failed",
            "exitCode": 1,
          },
        },
      ),
    );

    expect(event?.lifecycle, CodexCorrelatableItemLifecycle.completed);
    expect(event?.threadId, "thread-1");
    expect(event?.turnId, "turn-1");
    expect(event?.itemId, "exec-1");
    expect(event?.command, "printf marker");
    expect(event?.aggregatedOutput, "marker\n");
    expect(event?.status, CodexCommandExecutionStatus.failed);
    expect(event?.exitCode, 1);
  });

  test("preserves command identity when an outcome field is malformed", () {
    final event = parser.parse(
      notification: const CodexServerNotification(
        method: "item/completed",
        params: {
          "threadId": "thread-1",
          "turnId": "turn-1",
          "item": {
            "type": "commandExecution",
            "id": "exec-1",
            "status": "failed",
            "exitCode": "1",
          },
        },
      ),
    );

    expect(event?.threadId, "thread-1");
    expect(event?.turnId, "turn-1");
    expect(event?.itemId, "exec-1");
    expect(event?.status, CodexCommandExecutionStatus.failed);
    expect(event?.exitCode, isNull);
  });

  test("ignores unrelated item types and malformed identities", () {
    expect(
      parser.parse(
        notification: const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "thread-1",
            "item": {
              "type": "fileChange",
              "id": "edit-1",
              "status": "completed",
            },
          },
        ),
      ),
      isNull,
    );
    expect(
      parser.parse(
        notification: const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": " ",
            "item": {
              "type": "commandExecution",
              "id": "exec-1",
              "status": "completed",
            },
          },
        ),
      ),
      isNull,
    );
  });
}
