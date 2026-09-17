import "package:opencode_plugin/src/message_part_mapper.dart";
import "package:opencode_plugin/src/models/openapi/permission_request.g.dart";
import "package:opencode_plugin/src/models/sse_event_data.g.dart";
import "package:opencode_plugin/src/plugin_model_mapper.dart";
import "package:opencode_plugin/src/sse_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const snapshots = PluginModelMapper(messagePartMapper: MessagePartMapper(), maxTranscriptAttachmentBytes: 1024);
  final events = SseEventMapper();
  test("live and snapshot permissions use identical metadata, never pattern guesses", () {
    final cases = <(String, Map<String, dynamic>, PluginPermissionDetails)>[
      ("bash", {"command": "git status --short"}, const PluginPermissionDetails.command(command: "git status --short")),
      (
        "edit",
        {"filepath": "/full/path.txt"},
        const PluginPermissionDetails.fileChanges(
          files: [
            PluginPermissionFile(path: "/full/path.txt", operation: PluginPermissionFileOperation.write),
          ],
        ),
      ),
      (
        "edit",
        {
          "files": [
            {"filePath": "/new.txt", "type": "add"},
            {"filePath": "/old.txt", "type": "delete"},
          ],
        },
        const PluginPermissionDetails.fileChanges(
          files: [
            PluginPermissionFile(path: "/new.txt", operation: PluginPermissionFileOperation.create),
            PluginPermissionFile(path: "/old.txt", operation: PluginPermissionFileOperation.delete),
          ],
        ),
      ),
      (
        "webfetch",
        {"url": "https://example.com/full/path"},
        const PluginPermissionDetails.network(targets: ["https://example.com/full/path"], command: null),
      ),
      ("bash", {}, const PluginPermissionDetails.generic()),
      (
        "bash",
        {
          "command": ["printf", "ok"],
        },
        const PluginPermissionDetails.generic(),
      ),
      (
        "edit",
        {
          "files": [
            {"filePath": 1},
          ],
        },
        const PluginPermissionDetails.generic(),
      ),
      (
        "webfetch",
        {
          "url": {"host": "example.com"},
        },
        const PluginPermissionDetails.generic(),
      ),
      ("future", {"command": "not authoritative"}, const PluginPermissionDetails.generic()),
    ];
    for (final (permission, metadata, expected) in cases) {
      final json = <String, dynamic>{
        "id": "request",
        "sessionID": "child",
        "permission": permission,
        "patterns": ["*"],
        "metadata": metadata,
        "always": ["*"],
      };
      final snapshot = snapshots.mapPermission(PermissionRequest.fromJson(json), displaySessionId: "root");
      final event = events.map(
        SseEventData.fromJson({...json, "type": "permission.asked"}),
        displaySessionId: "root",
      );
      expect(event, isA<BridgeSsePermissionAsked>());
      final asked = event! as BridgeSsePermissionAsked;
      expect(snapshot.details, expected);
      expect(asked.details, snapshot.details);
      expect(asked.description, "*");
      expect(asked.sessionID, "child");
      expect(asked.displaySessionId, "root");
    }
  });
}
