import "package:codex_plugin/src/repositories/mappers/codex_tool_part_mapper.dart";
import "package:codex_plugin/src/repositories/models/codex_projected_tool.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const mapper = CodexToolPartMapper();

  for (final command in ["echo hello", null]) {
    test("ordinary tool projection uses explicit command provenance: $command", () {
      final part = mapper.map(
        sessionId: "root-1",
        tool: CodexProjectedTool(
          canonicalId: "call-1",
          tool: "shell",
          presentation: const CodexOrdinaryToolPresentation(),
          title: "echo hello",
          shellCommand: command,
          status: PluginToolStatus.completed,
          output: "hello",
          time: null,
          attachments: const [],
        ),
      ) as PluginMessagePartTool;

      expect(part.state.shellCommand, command);
      expect(part.state.output, "hello");
    });
  }

  for (final (agentCount, status, label) in [
    (2, PluginToolStatus.running, "Waiting for 2 sub-agents"),
    (1, PluginToolStatus.running, "Waiting for 1 sub-agent"),
    (null, PluginToolStatus.running, "Waiting for sub-agents"),
    (2, PluginToolStatus.completed, "Waited for 2 sub-agents"),
    (null, PluginToolStatus.completed, "Waited for sub-agents"),
  ]) {
    test("wait_agent reads as a sentence: $label", () {
      final part = mapper.map(
        sessionId: "root-1",
        tool: CodexProjectedTool(
          canonicalId: "call-1",
          tool: "wait_agent",
          presentation: CodexWaitAgentToolPresentation(agentCount: agentCount),
          title: null,
          shellCommand: null,
          status: status,
          output: null,
          time: null,
          attachments: const [],
        ),
      ) as PluginMessagePartTool;

      expect(part.tool, label);
      expect(part.state.title, isNull);
    });
  }
}
