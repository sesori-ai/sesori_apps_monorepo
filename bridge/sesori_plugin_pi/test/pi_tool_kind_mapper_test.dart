import "package:pi_plugin/src/repositories/mappers/pi_tool_kind_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("classifies Pi's built-in tool names", () {
    expect(PiToolKindMapper.map(name: "read"), PluginToolKind.read);
    expect(PiToolKindMapper.map(name: "edit"), PluginToolKind.edit);
    expect(PiToolKindMapper.map(name: "write"), PluginToolKind.edit);
    expect(PiToolKindMapper.map(name: "bash"), PluginToolKind.command);
    for (final name in ["grep", "find", "ls"]) {
      expect(PiToolKindMapper.map(name: name), PluginToolKind.search, reason: name);
    }
    expect(PiToolKindMapper.map(name: "subagent"), PluginToolKind.other);
  });
}
