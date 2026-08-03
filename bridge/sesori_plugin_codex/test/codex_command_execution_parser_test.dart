import "package:codex_plugin/src/api/models/codex_command_execution_dto.dart";
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
            "status": "failed",
            "exitCode": 1,
          },
        },
      ),
    );

    expect(event?.lifecycle, CodexCommandExecutionLifecycle.completed);
    expect(event?.threadId, "thread-1");
    expect(event?.turnId, "turn-1");
    expect(event?.itemId, "exec-1");
    expect(event?.status, CodexCommandExecutionStatus.failed);
    expect(event?.exitCode, 1);
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
