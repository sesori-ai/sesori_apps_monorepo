import "package:claude_plugin/claude_plugin.dart";
import "package:opencode_plugin/opencode_plugin.dart";
import "package:opencode_plugin/src/models/openapi/tool_part.g.dart";
import "package:pi_plugin/src/api/models/pi_event.dart";
import "package:pi_plugin/src/api/models/pi_session_history_dto.dart";
import "package:pi_plugin/src/repositories/mappers/pi_history_mapper.dart";
import "package:pi_plugin/src/repositories/mappers/pi_message_identity_builder.dart";
import "package:pi_plugin/src/services/pi_event_dispatcher.dart";
import "package:pi_plugin/src/trackers/pi_message_identity_tracker.dart";
import "package:pi_plugin/src/trackers/pi_tool_tracker.dart";
import "package:sesori_bridge/src/repositories/mappers/plugin_to_shared_mapping.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

ToolState _state({required PluginMessagePart part}) => (part.toShared(sessionId: "s") as MessagePartTool).state;

void main() {
  for (final failed in [false, true]) {
    test("Claude Agent outcome survives common projection failed=$failed", () {
      final block =
          const ClaudeContentMapper()
                  .map(
                    content: {
                      "type": "tool_use",
                      "id": "task",
                      "name": "Agent",
                      "input": {"description": "Explore", "prompt": "Explore project", "subagent_type": "explore"},
                    },
                  )
                  .single
              as ClaudeMappedToolUseContentBlock;
      final tracker = ClaudeToolTracker();
      tracker.start(
        sessionId: "s",
        messageId: "m",
        blockIndex: 0,
        toolId: block.id,
        name: block.name,
        input: block.input,
      );
      final outcome = "😀" * (maxToolOutputLength + 2);
      final part =
          tracker
                  .complete(
                    sessionId: "s",
                    toolId: block.id,
                    output: outcome,
                    isError: failed,
                    attachments: const [],
                    result: ClaudeToolUseResult.parse({"status": "completed", "agentId": "child"}),
                  )!
                  .toPart()!
                  .toShared(sessionId: "stable")
              as MessagePartSubtask;
      expect(part.childSessionID, "agent-child");
      expect(part.prompt, "Explore project");
      expect(part.description, "Explore");
      expect(part.agent, "explore");
      expect(part.taskState!.status, failed ? ToolStatus.error : ToolStatus.completed);
      expect(failed ? part.taskState!.error : part.taskState!.output, "😀" * maxToolOutputLength);
    });
    for (final shell in [false, true]) {
      test("Claude backend content live tracker/history projection shell=$shell failed=$failed", () {
        final name = shell ? "Bash" : "Read";
        final input = {"command": "pwd"};
        final content = {"type": "tool_use", "id": "c", "name": name, "input": input};
        final blocks = const ClaudeContentMapper().map(content: content);
        final block = blocks.single as ClaudeMappedToolUseContentBlock;
        final tracker = ClaudeToolTracker();
        tracker.start(
          sessionId: "s",
          messageId: "m",
          blockIndex: 0,
          toolId: block.id,
          name: block.name,
          input: block.input,
        );
        final result =
            const ClaudeContentMapper()
                    .map(
                      content: {
                        "type": "tool_result",
                        "tool_use_id": "c",
                        "content": "result",
                        "is_error": failed,
                      },
                    )
                    .single
                as ClaudeMappedToolResultContentBlock;
        final live = tracker
            .complete(
              sessionId: "s",
              toolId: "c",
              output: result.output,
              isError: failed,
              attachments: const [],
              result: const ClaudeToolUseResultAbsent(),
            )!
            .toPart()!;
        final history = const ClaudeHistoryMapper(content: ClaudeContentMapper())
            .map(
              sessionId: "s",
              agentId: null,
              residentTaskToolUseIds: const {},
              catalogModelId: null,
              records: [
                ClaudeTranscriptAssistantRecord(
                  id: "m",
                  model: null,
                  effort: null,
                  content: [content],
                  cwd: null,
                  timestamp: null,
                  isSidechain: null,
                  agentId: null,
                  gitBranch: null,
                  version: null,
                  sessionId: "s",
                  raw: const {},
                ),
                ClaudeTranscriptUserRecord(
                  id: "u",
                  content: [
                    {"type": "tool_result", "tool_use_id": "c", "content": "result", "is_error": failed},
                  ],
                  isMeta: false,
                  isVisibleInTranscriptOnly: false,
                  toolUseResult: const ClaudeToolUseResultAbsent(),
                  isTaskNotification: false,
                  cwd: null,
                  timestamp: null,
                  isSidechain: null,
                  agentId: null,
                  gitBranch: null,
                  version: null,
                  sessionId: "s",
                  raw: const {},
                ),
              ],
            )
            .expand((message) => message.parts)
            .whereType<PluginMessagePartTool>()
            .single;
        final state = _state(part: live);
        expect(state, _state(part: history));
        expect(state.shellCommand, shell ? "pwd" : null);
        expect(state.output, shell && !failed ? "result" : null);
        expect(state.error, shell && failed ? "result" : null);
        expect(state.status, failed ? ToolStatus.error : ToolStatus.completed);
      });

      test("Pi backend live/history projection shell=$shell failed=$failed", () {
        final name = shell ? "bash" : "read";
        final assistant = <String, dynamic>{
          "role": "assistant",
          "provider": "p",
          "model": "m",
          "timestamp": 1,
          "stopReason": "toolUse",
          "content": [
            {
              "type": "toolCall",
              "id": "c",
              "name": name,
              "arguments": {"command": "pwd"},
            },
          ],
        };
        final content = [
          {"type": "text", "text": "result"},
        ];
        final history = PiHistoryMapper(pluginId: "pi");
        final dispatcher = PiEventDispatcher(
          historyMapper: history,
          identityTracker: PiMessageIdentityTracker(pluginId: "pi"),
          toolTracker: PiToolTracker(),
        );
        dispatcher.map(
          sessionId: "s",
          event: PiEvent.parse(type: "message_end", json: {"type": "message_end", "message": assistant}),
        );
        final live = dispatcher
            .map(
              sessionId: "s",
              event: PiEvent.parse(
                type: "tool_execution_end",
                json: {
                  "type": "tool_execution_end",
                  "toolCallId": "c",
                  "toolName": name,
                  "isError": failed,
                  "result": {"content": content},
                },
              ),
            )
            .whereType<BridgeSseMessagePartUpdated>()
            .single
            .part;
        final replay = history
            .map(
              sessionId: "s",
              leafId: "r",
              identities: PiMessageIdentityBuilder(pluginId: "pi", sessionId: "s"),
              entries: [
                PiSessionEntryDto.fromJson({
                  "type": "message",
                  "id": "a",
                  "parentId": null,
                  "timestamp": "2026-09-08T10:00:00Z",
                  "message": assistant,
                }),
                PiSessionEntryDto.fromJson({
                  "type": "message",
                  "id": "r",
                  "parentId": "a",
                  "timestamp": "2026-09-08T10:00:01Z",
                  "message": {
                    "role": "toolResult",
                    "toolCallId": "c",
                    "toolName": name,
                    "content": content,
                    "isError": failed,
                    "timestamp": 2,
                  },
                }),
              ],
            )
            .expand((message) => message.parts)
            .whereType<PluginMessagePartTool>()
            .single;
        final state = _state(part: live);
        expect(state, _state(part: replay));
        expect(state.shellCommand, shell ? "pwd" : null);
        expect(state.output, shell && !failed ? "result" : null);
        expect(state.error, shell && failed ? "result" : null);
        expect(state.status, failed ? ToolStatus.error : ToolStatus.completed);
      });

      test("OpenCode typed live/REST tool projection shell=$shell failed=$failed", () {
        final raw = <String, dynamic>{
          "type": "tool",
          "id": "t",
          "sessionID": "s",
          "messageID": "m",
          "callID": "c",
          "tool": shell ? "bash" : "read",
          "state": {
            "status": failed ? "error" : "completed",
            "input": {"command": "pwd"},
            "title": "not authority",
            if (failed) "error": "result" else "output": "result",
            "metadata": <String, dynamic>{},
            "time": {"start": 0, "end": 1},
          },
        };
        // Both SSE and REST use the owning generated ToolPart and MessagePartMapper.
        final state = _state(part: const MessagePartMapper().mapPart(ToolPart.fromJson(raw)));
        expect(state.shellCommand, shell ? "pwd" : null);
        expect(state.title, shell ? "pwd" : null);
        expect(state.output, shell && !failed ? "result" : null);
        expect(state.error, shell && failed ? "result" : null);
        expect(state.status, failed ? ToolStatus.error : ToolStatus.completed);
      });
    }
  }
}
