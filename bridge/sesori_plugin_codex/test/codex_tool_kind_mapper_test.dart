import "package:codex_plugin/src/repositories/mappers/codex_tool_kind_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("classifies the canonical Codex tool names", () {
    expect(CodexToolKindMapper.map(tool: "shell"), PluginToolKind.command);
    expect(CodexToolKindMapper.map(tool: "edit"), PluginToolKind.edit);
    expect(CodexToolKindMapper.map(tool: "web_search"), PluginToolKind.search);
    expect(CodexToolKindMapper.map(tool: "mcp"), PluginToolKind.other);
    expect(CodexToolKindMapper.map(tool: "image_generation"), PluginToolKind.other);
  });
}
