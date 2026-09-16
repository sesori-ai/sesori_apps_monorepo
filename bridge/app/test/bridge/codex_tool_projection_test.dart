import "dart:convert";

import "package:codex_plugin/src/api/models/codex_command_execution_dto.dart";
import "package:codex_plugin/src/api/models/codex_correlatable_item_event_dto.dart";
import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/repositories/codex_tool_lifecycle_tracker.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_rollout_tool_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_tool_part_mapper.dart";
import "package:codex_plugin/src/repositories/models/codex_projected_tool.dart";
import "package:sesori_bridge/src/repositories/mappers/plugin_to_shared_mapping.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _rollout = CodexRolloutToolMapper(imageAttachmentMapper: CodexImageAttachmentMapper());
CodexRolloutLineDto _line({required Map<String, dynamic> payload}) => CodexRolloutLineDto.fromJson({
  "type": "response_item",
  "timestamp": "2026-09-08T10:00:00Z",
  "payload": payload,
});
ToolState _project({required CodexProjectedTool tool}) =>
    (const CodexToolPartMapper().map(sessionId: "s", tool: tool).toShared(sessionId: "s") as MessagePartTool).state;

void main() {
  final cases = [
    (name: "exec", input: 'text(await tools.exec_command({"workdir": "/repo", "cmd": "pwd"}));', command: "pwd"),
    (name: "exec", input: 'console.log("non-shell data")', command: null),
    (name: "exec", input: 'console.log(\'tools.exec_command({cmd: "fake"})\')', command: null),
    (name: "exec", input: '// tools.exec_command({cmd: "fake"})', command: null),
    (name: "exec", input: 'text(await tools.exec_command({cmd: "echo real"}));', command: "echo real"),
    (name: "exec", input: "text(await tools.exec_command  ( { 'cmd' : 'echo real' } ));", command: "echo real"),
    (name: "exec", input: 'text(await tools.exec_command({cmd: "echo " + secret}));', command: null),
    (
      name: "exec",
      input: 'await tools.exec_command({cmd: "one"}); await tools.exec_command({cmd: "two"});',
      command: null,
    ),
    (name: "exec_command", input: jsonEncode({"cmd": "echo real"}), command: "echo real"),
    (name: "shell_like_tool", input: jsonEncode({"command": "not authority"}), command: null),
  ];
  for (final fixture in cases) {
    for (final failed in [false, true]) {
      test("Codex ${fixture.name} ${fixture.input} live/replay failed=$failed", () {
        final lines = [
          _line(
            payload: {
              "type": fixture.name == "exec" ? "custom_tool_call" : "function_call",
              "name": fixture.name,
              "call_id": "c",
              "input": fixture.input,
              "arguments": fixture.input,
            },
          ),
          _line(
            payload: {
              "type": fixture.name == "exec" ? "custom_tool_call_output" : "function_call_output",
              "call_id": "c",
              "output": "Process exited with code ${failed ? 1 : 0}\nFinal Output:\nresult",
            },
          ),
        ];
        final live = CodexToolLifecycleTracker(rolloutToolMapper: _rollout);
        final replay = CodexToolLifecycleTracker(rolloutToolMapper: _rollout);
        for (final line in lines) {
          final state = _project(
            tool: live.observeRolloutLine(threadId: "s", line: line).single,
          );
          expect(
            state,
            _project(
              tool: replay.observeRolloutLine(threadId: "s", line: line).single,
            ),
          );
          expect(state.shellCommand, fixture.command);
          expect(state.title, fixture.command);
          if (line == lines.last) {
            expect(state.status, failed ? ToolStatus.error : ToolStatus.completed);
            if (fixture.command != null) {
              expect(state.output, contains("result"));
              expect(state.error, failed ? contains("result") : isNull);
            }
          }
          if (fixture.command == null) {
            expect(state.output, isNull);
            expect(state.error, isNull);
          }
        }
      });
    }
  }
  test("correlated commandExecution supplies command for expression-based code mode and updates it", () {
    final tracker = CodexToolLifecycleTracker(rolloutToolMapper: _rollout);
    final initial = tracker
        .observeRolloutLine(
          threadId: "s",
          line: _line(
            payload: {
              "type": "custom_tool_call",
              "name": "exec",
              "call_id": "c",
              "input": "const command = 'pwd'; text(await tools.exec_command({cmd: command}));",
              "metadata": {"turn_id": "turn"},
            },
          ),
        )
        .single;
    expect(_project(tool: initial).shellCommand, isNull);
    for (final completed in [false, true]) {
      final tool = tracker.observeCorrelatableAppServerItem(
        event: CodexCommandExecutionEventDto(
          lifecycle: completed ? CodexCorrelatableItemLifecycle.completed : CodexCorrelatableItemLifecycle.started,
          threadId: "s",
          turnId: "turn",
          itemId: "c",
          command: completed ? "echo updated" : "pwd",
          aggregatedOutput: completed ? "result" : null,
          status: completed ? CodexCommandExecutionStatus.completed : CodexCommandExecutionStatus.inProgress,
          exitCode: completed ? 1 : null,
        ),
        notification: CodexServerNotification(method: completed ? "item/completed" : "item/started", params: const {}),
      );
      final state = _project(tool: tool!);
      expect(state.shellCommand, completed ? "echo updated" : "pwd");
      if (completed) {
        expect(state.output, "result");
        expect(state.error, "result");
      }
    }
  });
}
