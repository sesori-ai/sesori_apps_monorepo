import "package:claude_plugin/src/repositories/mappers/claude_permission_details_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const mapper = ClaudePermissionDetailsMapper();
  test("normalizes only known built-in inputs without treating writes as creation", () {
    expect(
      mapper.map(tool: "Bash", input: {"command": "printf '[literal] *'"}),
      const PluginPermissionDetails.command(command: "printf '[literal] *'"),
    );
    for (final tool in ["Edit", "MultiEdit", "Write"]) {
      expect(
        mapper.map(tool: tool, input: {"file_path": "/a/full/path.txt"}),
        const PluginPermissionDetails.fileChanges(
          files: [
            PluginPermissionFile(path: "/a/full/path.txt", operation: PluginPermissionFileOperation.write),
          ],
        ),
      );
    }
    expect(
      mapper.map(tool: "WebFetch", input: {"url": "https://example.com/full/path?q=1"}),
      const PluginPermissionDetails.network(targets: ["https://example.com/full/path?q=1"], command: null),
    );
    expect(
      mapper.map(tool: "mcp__custom__Bash", input: {"command": "not a shell schema"}),
      const PluginPermissionDetails.generic(),
    );
    expect(mapper.map(tool: "Bash", input: {}), const PluginPermissionDetails.generic());
  });
}
