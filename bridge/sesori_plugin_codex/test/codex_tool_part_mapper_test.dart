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
}
