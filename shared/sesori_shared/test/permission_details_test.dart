import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const legacy = {
    "id": "request",
    "sessionID": "child",
    "displaySessionId": "root",
    "tool": "native-tool",
    "description": "Keep **all** original details",
    "allowAlways": false,
  };
  const variants = <PermissionDetails>[
    PermissionDetails.generic(),
    PermissionDetails.command(command: r"printf '%s\n' '[literal] * command'"),
    PermissionDetails.fileChanges(
      files: [
        PermissionFile(path: "/workspace/created.txt", operation: PermissionFileOperation.create),
        PermissionFile(path: r"C:\workspace\unknown.txt", operation: null),
      ],
    ),
    PermissionDetails.network(targets: ["example.com", "https://example.com/full/path?q=1"], command: null),
    PermissionDetails.network(targets: ["example.com"], command: "curl https://example.com"),
  ];

  test("missing and future details preserve the released generic permission", () {
    for (final extra in [
      <String, dynamic>{},
      {
        "details": {"kind": "future-kind", "data": "opaque"},
      },
    ]) {
      final pending = PendingPermission.fromJson({...legacy, ...extra});
      expect(pending.details, const PermissionDetails.generic());
      expect(pending.description, legacy["description"]);
      final event = SesoriSseEvent.fromJson({
        ...legacy,
        ...extra,
        "type": "permission.asked",
        "requestID": "request",
      }) as SesoriPermissionAsked;
      expect(event.details, const PermissionDetails.generic());
      expect(event.allowAlways, isFalse);
      expect(event.sessionID, "child");
    }
  });

  test("every variant survives snapshot and event JSON with legacy fields intact", () {
    for (final details in variants) {
      final pending = PendingPermission.fromJson(legacy).copyWith(details: details);
      final json = jsonDecodeMap(jsonEncode(pending));
      for (final entry in legacy.entries) {
        expect(json[entry.key], entry.value);
      }
      expect(PendingPermission.fromJson(json), pending);
      final event = SesoriSseEvent.permissionAsked(
        requestID: pending.id,
        sessionID: pending.sessionID,
        displaySessionId: pending.displaySessionId,
        tool: pending.tool,
        description: pending.description,
        allowAlways: pending.allowAlways,
        details: details,
      );
      expect(SesoriSseEvent.fromJson(jsonDecodeMap(jsonEncode(event))), event);
    }
  });

  test("future file operation is unknown rather than a guessed write", () {
    final file = PermissionFile.fromJson({"path": "/known/path", "operation": "future-operation"});
    expect(file.path, "/known/path");
    expect(file.operation, isNull);
  });
}
