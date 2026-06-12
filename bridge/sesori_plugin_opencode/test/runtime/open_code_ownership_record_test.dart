import "dart:convert";

import "package:opencode_plugin/src/runtime/open_code_ownership_record.dart";
import "package:test/test.dart";

void main() {
  final record = OpenCodeOwnershipRecord(
    ownerSessionId: "900:bridge-marker",
    openCodePid: 4242,
    openCodeStartMarker: "oc-marker",
    openCodeExecutablePath: "/usr/local/bin/opencode",
    openCodeCommand: "/usr/local/bin/opencode",
    openCodeArgs: const <String>["serve", "--port", "51000", "--hostname", "127.0.0.1"],
    port: 51000,
    bridgePid: 900,
    bridgeStartMarker: "bridge-marker",
    startedAt: DateTime.utc(2026, 6, 1, 9, 30, 15),
    status: OpenCodeOwnershipStatus.ready,
  );

  test("serializes to the frozen schema bytes (keys in declaration order)", () {
    final json = record.toJson();
    expect(
      jsonEncode(json),
      equals(
        '{"ownerSessionId":"900:bridge-marker",'
        '"openCodePid":4242,'
        '"openCodeStartMarker":"oc-marker",'
        '"openCodeExecutablePath":"/usr/local/bin/opencode",'
        '"openCodeCommand":"/usr/local/bin/opencode",'
        '"openCodeArgs":["serve","--port","51000","--hostname","127.0.0.1"],'
        '"port":51000,'
        '"bridgePid":900,'
        '"bridgeStartMarker":"bridge-marker",'
        '"startedAt":"2026-06-01T09:30:15.000Z",'
        '"status":"ready"}',
      ),
    );
  });

  test("round-trips through JSON", () {
    final decoded = OpenCodeOwnershipRecord.fromJson(
      jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
    );
    expect(decoded, equals(record));
  });

  test("tolerates a null start marker (Windows / spawn race)", () {
    final source = record.copyWith(
      openCodeStartMarker: null,
      bridgeStartMarker: null,
      startedAt: DateTime.utc(2026, 6, 1),
    );
    final decoded = OpenCodeOwnershipRecord.fromJson(
      jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.openCodeStartMarker, isNull);
    expect(decoded.bridgeStartMarker, isNull);
  });

  test("serializes each status enum value to its lowercase name", () {
    String statusOf(OpenCodeOwnershipStatus status) =>
        record.copyWith(startedAt: DateTime.utc(2026), status: status).toJson()["status"] as String;
    expect(statusOf(OpenCodeOwnershipStatus.starting), equals("starting"));
    expect(statusOf(OpenCodeOwnershipStatus.ready), equals("ready"));
    expect(statusOf(OpenCodeOwnershipStatus.stopping), equals("stopping"));
  });
}
