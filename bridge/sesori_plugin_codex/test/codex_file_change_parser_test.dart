import "package:codex_plugin/src/api/models/codex_correlatable_item_event_dto.dart";
import "package:codex_plugin/src/api/models/codex_file_change_dto.dart";
import "package:codex_plugin/src/api/parsers/codex_file_change_parser.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:test/test.dart";

void main() {
  const parser = CodexFileChangeParser();

  test("parses file-change lifecycle and identity into typed state", () {
    final event = parser.parse(
      notification: const CodexServerNotification(
        method: "item/completed",
        params: {
          "threadId": " thread-1 ",
          "turnId": " turn-1 ",
          "item": {
            "type": "fileChange",
            "id": " edit-1 ",
            "status": "completed",
            "changes": [
              {
                "path": "marker.txt",
                "kind": {"type": "add"},
                "diff": "+marker",
              },
            ],
          },
        },
      ),
    );

    expect(event?.lifecycle, CodexCorrelatableItemLifecycle.completed);
    expect(event?.threadId, "thread-1");
    expect(event?.turnId, "turn-1");
    expect(event?.itemId, "edit-1");
    expect(event?.status, CodexFileChangeStatus.completed);
  });

  test("preserves identity with an unknown status", () {
    final event = parser.parse(
      notification: const CodexServerNotification(
        method: "item/started",
        params: {
          "threadId": "thread-1",
          "item": {
            "type": "fileChange",
            "id": "edit-1",
            "status": "future-status",
          },
        },
      ),
    );

    expect(event?.lifecycle, CodexCorrelatableItemLifecycle.started);
    expect(event?.status, CodexFileChangeStatus.unknown);
  });

  test("ignores unrelated items and malformed identities", () {
    expect(
      parser.parse(
        notification: const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "thread-1",
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
    expect(
      parser.parse(
        notification: const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": " ",
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
  });
}
