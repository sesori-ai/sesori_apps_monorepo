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
        "subagentType": {"unspecified": <String, Object?>{}},
      });
      final output = CursorTaskOutputDto.fromJson(const {"isBackground": false});

      expect(
        (update.sessionUpdate, update.status),
        (CursorTaskReplayUpdateKind.toolCall, CursorTaskReplayStatus.pending),
      );
      expect(input.subagentType?.unspecified, isA<CursorSubagentUnspecifiedDto>());
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
      expect(CursorTaskReplaySubagentTypeDto.fromJson(const {}).unspecified, isNull);
      expect(
        CursorTaskReplaySubagentTypeDto.fromJson(const {
          "futureAgent": <String, Object?>{},
        }).unspecified,
        isNull,
      );
      expect(
        () => CursorTaskReplayInputDto.fromJson(const {"_toolName": "task", "prompt": 7}),
        throwsA(anything),
      );
      expect(() => CursorTaskReplayUpdateDto.fromJson(const {}), throwsA(anything));
    });
  });

  group("Cursor completed Task output DTO", () {
    test("parses explicit foreground output", () {
      expect(CursorTaskOutputDto.fromJson(const {"isBackground": false}).isBackground, isFalse);
    });

    test("missing or malformed terminal facts do not parse", () {
      expect(() => CursorTaskOutputDto.fromJson(const {}), throwsA(anything));
      expect(
        () => CursorTaskOutputDto.fromJson(const {"isBackground": "false"}),
        throwsA(anything),
      );
    });
  });
}
