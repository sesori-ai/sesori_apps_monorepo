import "dart:convert";

import "package:codex_plugin/src/runtime/codex_ownership_record.dart";
import "package:codex_plugin/src/runtime/codex_record_mapper.dart";
import "package:test/test.dart";

void main() {
  final record = CodexOwnershipRecord(
    ownerSessionId: "900:bridge-marker",
    codexPid: 4242,
    codexStartMarker: "codex-marker",
    codexExecutablePath: "/usr/local/bin/codex",
    codexCommand: "/usr/local/bin/codex",
    codexArgs: const <String>["app-server", "--listen", "ws://127.0.0.1:51000"],
    port: 51000,
    bridgePid: 900,
    bridgeStartMarker: "bridge-marker",
    startedAt: DateTime.utc(2026, 6, 1, 9, 30, 15),
    status: CodexOwnershipStatus.ready,
  );

  test("serializes with keys in declaration order", () {
    expect(
      jsonEncode(record.toJson()),
      equals(
        '{"ownerSessionId":"900:bridge-marker",'
        '"codexPid":4242,'
        '"codexStartMarker":"codex-marker",'
        '"codexExecutablePath":"/usr/local/bin/codex",'
        '"codexCommand":"/usr/local/bin/codex",'
        '"codexArgs":["app-server","--listen","ws://127.0.0.1:51000"],'
        '"port":51000,'
        '"bridgePid":900,'
        '"bridgeStartMarker":"bridge-marker",'
        '"startedAt":"2026-06-01T09:30:15.000Z",'
        '"status":"ready"}',
      ),
    );
  });

  test("round-trips through JSON", () {
    final decoded = CodexOwnershipRecord.fromJson(
      jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
    );
    expect(decoded, equals(record));
  });

  test("tolerates a null start marker (Windows / spawn race)", () {
    final source = record.copyWith(codexStartMarker: null, bridgeStartMarker: null);
    final decoded = CodexOwnershipRecord.fromJson(
      jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.codexStartMarker, isNull);
    expect(decoded.bridgeStartMarker, isNull);
  });

  group("CodexRecordMapper", () {
    const mapper = CodexRecordMapper();

    test("extracts the identity fields the supervisor matches on", () {
      expect(mapper.ownerSessionIdOf(record: record), equals("900:bridge-marker"));
      expect(mapper.runtimePidOf(record: record), equals(4242));
      expect(mapper.runtimeStartMarkerOf(record: record), equals("codex-marker"));
      expect(mapper.runtimeExecutablePathOf(record: record), equals("/usr/local/bin/codex"));
      expect(mapper.bridgePidOf(record: record), equals(900));
      expect(mapper.bridgeStartMarkerOf(record: record), equals("bridge-marker"));
    });

    test("rebuilds the spawn command line (command + args joined)", () {
      expect(
        mapper.runtimeCommandLineOf(record: record),
        equals("/usr/local/bin/codex app-server --listen ws://127.0.0.1:51000"),
      );
    });

    test("mark* flips only the status field", () {
      expect(mapper.markReady(record: record.copyWith(status: CodexOwnershipStatus.starting)).status,
          equals(CodexOwnershipStatus.ready));
      expect(mapper.markStopping(record: record).status, equals(CodexOwnershipStatus.stopping));
    });

    test("toJson/fromJson defer to the freezed model", () {
      final json = mapper.toJson(record: record);
      expect(mapper.fromJson(json: json), equals(record));
    });
  });
}
