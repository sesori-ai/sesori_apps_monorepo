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
}
