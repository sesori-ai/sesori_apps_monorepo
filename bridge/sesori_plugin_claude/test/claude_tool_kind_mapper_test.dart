import "package:claude_plugin/src/repositories/mappers/claude_tool_kind_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("classifies Claude Code's built-in tool names", () {
    expect(ClaudeToolKindMapper.map(name: "Read"), PluginToolKind.read);
    for (final name in ["Edit", "MultiEdit", "NotebookEdit", "Write"]) {
      expect(ClaudeToolKindMapper.map(name: name), PluginToolKind.edit, reason: name);
    }
    expect(ClaudeToolKindMapper.map(name: "Bash"), PluginToolKind.command);
    for (final name in ["Grep", "Glob", "LS", "WebSearch"]) {
      expect(ClaudeToolKindMapper.map(name: name), PluginToolKind.search, reason: name);
    }
    expect(ClaudeToolKindMapper.map(name: "WebFetch"), PluginToolKind.other);
    expect(ClaudeToolKindMapper.map(name: "mcp__server__tool"), PluginToolKind.other);
    expect(ClaudeToolKindMapper.map(name: null), PluginToolKind.other);
  });
}
