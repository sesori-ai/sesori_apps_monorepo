import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const mapper = AcpPermissionDetailsMapper();
  test("uses standard diff and location evidence, not title or arbitrary inputs", () {
    expect(
      mapper.map(
        toolCall: {
          "kind": "edit",
          "title": "Edit files",
          "content": [
            {"type": "diff", "path": "/new.txt", "newText": "new"},
            {"type": "diff", "path": "/existing.txt", "oldText": "", "newText": "new"},
          ],
          "locations": [
            {"path": "/new.txt"},
            {"path": "/another.txt"},
          ],
        },
        command: null,
      ),
      const PluginPermissionDetails.fileChanges(
        files: [
          PluginPermissionFile(path: "/new.txt", operation: PluginPermissionFileOperation.create),
          PluginPermissionFile(path: "/existing.txt", operation: PluginPermissionFileOperation.write),
          PluginPermissionFile(path: "/another.txt", operation: PluginPermissionFileOperation.write),
        ],
      ),
    );
    expect(
      mapper.map(
        toolCall: {
          "kind": "execute",
          "title": "rm -rf /",
          "rawInput": {"command": "untyped"},
        },
        command: null,
      ),
      const PluginPermissionDetails.generic(),
    );
    expect(
      mapper.map(
        toolCall: {
          "kind": "read",
          "locations": [
            {"path": "/read.txt"},
          ],
        },
        command: null,
      ),
      const PluginPermissionDetails.generic(),
    );
  });
  test("malformed optional fields keep permissions actionable", () {
    for (final toolCall in <Map<String, dynamic>>[
      {"locations": "not a list"},
      {
        "content": [
          {"type": "diff", "path": 1},
        ],
      },
    ]) {
      expect(mapper.map(toolCall: toolCall, command: null), const PluginPermissionDetails.generic());
      expect(
        mapper.map(toolCall: toolCall, command: "printf ok"),
        const PluginPermissionDetails.command(command: "printf ok"),
      );
    }
  });

  test("keeps authoritative commands and standard fetch resource URLs complete", () {
    expect(
      mapper.map(toolCall: {}, command: "printf '[full] * command'"),
      const PluginPermissionDetails.command(command: "printf '[full] * command'"),
    );
    expect(
      mapper.map(
        toolCall: {
          "kind": "fetch",
          "content": [
            {
              "type": "content",
              "content": {"type": "resource_link", "uri": "https://example.com/full/path"},
            },
          ],
        },
        command: null,
      ),
      const PluginPermissionDetails.network(targets: ["https://example.com/full/path"], command: null),
    );
    expect(
      mapper.map(
        toolCall: {
          "kind": "future",
          "content": [
            {"type": "future"},
          ],
        },
        command: null,
      ),
      const PluginPermissionDetails.generic(),
    );
  });
}
