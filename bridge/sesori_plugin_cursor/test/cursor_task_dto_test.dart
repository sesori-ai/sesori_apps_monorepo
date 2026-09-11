import "package:cursor_plugin/src/api/models/cursor_task_dto.dart";
import "package:test/test.dart";

void main() {
  group("CursorTaskInputDto", () {
    test("identifies the standard Task tool", () {
      expect(
        CursorTaskInputDto.fromJson(const {"_toolName": "task"}).toolName,
        CursorTaskTool.task,
      );
    });

    test("maps an unknown non-null tool name to unknown", () {
      expect(
        CursorTaskInputDto.fromJson(const {"_toolName": "future_task"}).toolName,
        CursorTaskTool.unknown,
      );
    });

    test("does not default a missing tool name", () {
      expect(() => CursorTaskInputDto.fromJson(const {}), throwsArgumentError);
    });
  });

  group("Cursor replay Task DTOs", () {
    test("parses the update envelope and Task-specific nested facts separately", () {
      final update = CursorTaskReplayUpdateDto.fromJson(const {
        "sessionUpdate": "tool_call",
        "toolCallId": "task-1",
        "status": "pending",
      });
      final input = CursorTaskReplayInputDto.fromJson(const {
        "_toolName": "task",
        "prompt": "Inspect code",
        "description": "Inspect",
        "subagentType": {"custom": "unspecified"},
      });
      final output = CursorTaskOutputDto.fromJson(const {"isBackground": false});

      expect(
        (update.sessionUpdate, update.status, input.subagentType?.custom),
        (CursorTaskReplayUpdateKind.toolCall, CursorTaskReplayStatus.pending, CursorSubagentType.unspecified),
      );
      expect(output.isBackground, isFalse);
    });

    test("preserves nullable enums and rejects malformed known fields", () {
      final unknown = CursorTaskReplayUpdateDto.fromJson(const {
        "sessionUpdate": "future_update",
        "status": "future_status",
      });
      expect(
        (unknown.sessionUpdate, unknown.status),
        (CursorTaskReplayUpdateKind.unknown, CursorTaskReplayStatus.unknown),
      );
      expect(CursorSubagentTypeDto.fromJson(const {}).custom, isNull);
      expect(
        () => CursorTaskReplayInputDto.fromJson(const {"_toolName": "task", "prompt": 7}),
        throwsA(anything),
      );
      expect(() => CursorTaskReplayUpdateDto.fromJson(const {}), throwsA(anything));
    });
  });

  group("Cursor completed Task DTOs", () {
    test("parses explicit foreground output and observed request presentation", () {
      expect(CursorTaskOutputDto.fromJson(const {"isBackground": false}).isBackground, isFalse);

      final request = CursorTaskRequestDto.fromJson(const {
        "toolCallId": "task-1",
        "agentId": "not-a-child-session",
        "description": "Inspect",
        "prompt": "Inspect code",
        "subagentType": {"custom": "unspecified"},
        "model": "ignored-model",
        "durationMs": 42,
      });
      expect(request.toolCallId, "task-1");
      expect(request.description, "Inspect");
      expect(request.prompt, "Inspect code");
      expect(request.subagentType.custom, CursorSubagentType.unspecified);
    });

    test("missing custom stays null and unfamiliar non-null custom becomes unknown", () {
      expect(CursorSubagentTypeDto.fromJson(const {}).custom, isNull);
      expect(
        CursorSubagentTypeDto.fromJson(const {"custom": "future-agent"}).custom,
        CursorSubagentType.unknown,
      );
    });

    test("missing or malformed terminal facts do not parse", () {
      expect(() => CursorTaskOutputDto.fromJson(const {}), throwsA(anything));
      expect(
        () => CursorTaskOutputDto.fromJson(const {"isBackground": "false"}),
        throwsA(anything),
      );
      expect(
        () => CursorTaskRequestDto.fromJson(const {
          "toolCallId": "task-1",
          "description": "Inspect",
          "prompt": "Inspect code",
        }),
        throwsA(anything),
      );
      expect(
        () => CursorTaskRequestDto.fromJson(const {
          "toolCallId": "task-1",
          "description": "Inspect",
          "prompt": "Inspect code",
          "subagentType": "unspecified",
        }),
        throwsA(anything),
      );
    });
  });
}
