import "dart:async";
import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  group("HostJsonRuntimeOwnershipRepository", () {
    late _FakeHostJsonStore store;
    late HostJsonRuntimeOwnershipRepository<_TestRecord> repository;

    setUp(() {
      store = _FakeHostJsonStore();
      repository = HostJsonRuntimeOwnershipRepository<_TestRecord>(
        store: store,
        mapper: const _TestRecordMapper(),
        fileName: "opencode-processes.json",
        clock: const _FixedClock(),
      );
    });

    test("readAll and readByOwnerSessionId return decoded records", () async {
      final record = _record(ownerSessionId: "owner-a", pid: 401, status: _TestStatus.ready);
      store.files["opencode-processes.json"] = jsonEncode(<String, dynamic>{"owner-a": record.toJson()});

      expect(
        (await repository.readAll()).map((entry) => entry.toJson()),
        equals(<Map<String, dynamic>>[record.toJson()]),
      );
      expect((await repository.readByOwnerSessionId(ownerSessionId: "owner-a"))?.toJson(), equals(record.toJson()));
      expect(store.calls, equals(<String>["read:opencode-processes.json", "read:opencode-processes.json"]));
    });

    test("upsert writes root map keyed by ownerSessionId through update", () async {
      final first = _record(ownerSessionId: "owner-a", pid: 401, status: _TestStatus.ready);
      final second = _record(ownerSessionId: "owner-b", pid: 402, status: _TestStatus.starting);

      await repository.upsert(record: first);
      await repository.upsert(record: second);

      expect(store.calls, equals(<String>["update:opencode-processes.json", "update:opencode-processes.json"]));
      expect(
        store.files["opencode-processes.json"],
        equals(jsonEncode(<String, dynamic>{"owner-a": first.toJson(), "owner-b": second.toJson()})),
      );
    });

    test("deleteByOwnerSessionId deletes file when last record removed", () async {
      final record = _record(ownerSessionId: "owner-a", pid: 401, status: _TestStatus.ready);
      store.files["opencode-processes.json"] = jsonEncode(<String, dynamic>{"owner-a": record.toJson()});

      await repository.deleteByOwnerSessionId(ownerSessionId: "owner-a");

      expect(store.calls, equals(<String>["update:opencode-processes.json"]));
      expect(store.files.containsKey("opencode-processes.json"), isFalse);
    });

    test("deleteByOwnerSessionId leaves file unchanged when record is absent", () async {
      final record = _record(ownerSessionId: "owner-a", pid: 401, status: _TestStatus.ready);
      final contents = jsonEncode(<String, dynamic>{"owner-a": record.toJson()});
      store.files["opencode-processes.json"] = contents;

      await repository.deleteByOwnerSessionId(ownerSessionId: "missing");

      expect(store.files["opencode-processes.json"], equals(contents));
    });

    test("deleteByOwnerSessionId preserves non-canonical bytes when record is absent", () async {
      final record = _record(ownerSessionId: "owner-a", pid: 401, status: _TestStatus.ready);
      final prettyContents = const JsonEncoder.withIndent(
        "  ",
      ).convert(<String, dynamic>{"owner-a": record.toJson()});
      store.files["opencode-processes.json"] = prettyContents;

      await repository.deleteByOwnerSessionId(ownerSessionId: "missing");

      expect(store.files["opencode-processes.json"], equals(prettyContents));
    });

    test("corrupt file is quarantined with legacy-compatible name and treated as empty", () async {
      store.files["opencode-processes.json"] = "{";

      expect(await repository.readAll(), isEmpty);

      expect(
        store.calls,
        equals(<String>[
          "read:opencode-processes.json",
          "quarantine:opencode-processes.json:opencode-processes.invalid.2026-05-15T12-30-01-234Z.json",
        ]),
      );
      expect(store.files.containsKey("opencode-processes.json"), isFalse);
      expect(store.files["opencode-processes.invalid.2026-05-15T12-30-01-234Z.json"], equals("{"));
    });

    test("non-map file is quarantined with legacy-compatible name and treated as empty", () async {
      store.files["opencode-processes.json"] = jsonEncode(<String>["not", "a", "map"]);

      expect(await repository.readByOwnerSessionId(ownerSessionId: "owner-a"), isNull);

      expect(
        store.calls.last,
        equals("quarantine:opencode-processes.json:opencode-processes.invalid.2026-05-15T12-30-01-234Z.json"),
      );
    });

    test("upsert over corrupt file quarantines then writes the new record", () async {
      final record = _record(ownerSessionId: "owner-a", pid: 401, status: _TestStatus.ready);
      store.files["opencode-processes.json"] = "{";

      await repository.upsert(record: record);

      expect(
        store.calls,
        equals(<String>[
          "update:opencode-processes.json",
          "quarantine:opencode-processes.json:opencode-processes.invalid.2026-05-15T12-30-01-234Z.json",
        ]),
      );
      expect(store.files["opencode-processes.invalid.2026-05-15T12-30-01-234Z.json"], equals("{"));
      expect(store.files["opencode-processes.json"], equals(jsonEncode(<String, dynamic>{"owner-a": record.toJson()})));
    });

    test("deleteByOwnerSessionId over corrupt file quarantines without resurrecting corrupt bytes", () async {
      store.files["opencode-processes.json"] = "{";

      await repository.deleteByOwnerSessionId(ownerSessionId: "owner-a");

      expect(
        store.calls,
        equals(<String>[
          "update:opencode-processes.json",
          "quarantine:opencode-processes.json:opencode-processes.invalid.2026-05-15T12-30-01-234Z.json",
        ]),
      );
      expect(store.files["opencode-processes.invalid.2026-05-15T12-30-01-234Z.json"], equals("{"));
      expect(store.files.containsKey("opencode-processes.json"), isFalse);
    });

    test("byte-compatible legacy-shaped records round-trip and write golden bytes", () async {
      final first = _record(ownerSessionId: "owner-a", pid: 401, status: _TestStatus.ready);
      final second = _record(ownerSessionId: "owner-b", pid: 402, status: _TestStatus.stopping);

      await repository.upsert(record: first);
      await repository.upsert(record: second);

      final golden = jsonEncode(<String, dynamic>{"owner-a": first.toJson(), "owner-b": second.toJson()});
      expect(store.files["opencode-processes.json"], equals(golden));

      final roundTrip = await repository.readAll();
      expect(roundTrip.map((entry) => entry.toJson()), equals(<Map<String, dynamic>>[first.toJson(), second.toJson()]));
    });
  });
}

_TestRecord _record({required String ownerSessionId, required int pid, required _TestStatus status}) {
  return _TestRecord(
    ownerSessionId: ownerSessionId,
    openCodePid: pid,
    openCodeStartMarker: "open-start-$pid",
    openCodeExecutablePath: "/usr/local/bin/opencode",
    openCodeCommand: "/usr/local/bin/opencode",
    openCodeArgs: const <String>["serve", "--port", "50123", "--hostname", "127.0.0.1"],
    port: 50123,
    bridgePid: 900,
    bridgeStartMarker: "bridge-start",
    startedAt: DateTime.utc(2026, 5, 15, 12),
    status: status,
  );
}

enum _TestStatus { starting, ready, stopping }

class _TestRecord {
  const _TestRecord({
    required this.ownerSessionId,
    required this.openCodePid,
    required this.openCodeStartMarker,
    required this.openCodeExecutablePath,
    required this.openCodeCommand,
    required this.openCodeArgs,
    required this.port,
    required this.bridgePid,
    required this.bridgeStartMarker,
    required this.startedAt,
    required this.status,
  });

  final String ownerSessionId;
  final int openCodePid;
  final String? openCodeStartMarker;
  final String openCodeExecutablePath;
  final String openCodeCommand;
  final List<String> openCodeArgs;
  final int port;
  final int bridgePid;
  final String? bridgeStartMarker;
  final DateTime startedAt;
  final _TestStatus status;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "ownerSessionId": ownerSessionId,
      "openCodePid": openCodePid,
      "openCodeStartMarker": openCodeStartMarker,
      "openCodeExecutablePath": openCodeExecutablePath,
      "openCodeCommand": openCodeCommand,
      "openCodeArgs": openCodeArgs,
      "port": port,
      "bridgePid": bridgePid,
      "bridgeStartMarker": bridgeStartMarker,
      "startedAt": startedAt.toIso8601String(),
      "status": status.name,
    };
  }
}

class _TestRecordMapper implements RuntimeRecordMapper<_TestRecord> {
  const _TestRecordMapper();

  @override
  Map<String, dynamic> toJson({required _TestRecord record}) => record.toJson();

  @override
  _TestRecord fromJson({required Map<String, dynamic> json}) {
    return _TestRecord(
      ownerSessionId: json["ownerSessionId"] as String,
      openCodePid: (json["openCodePid"] as num).toInt(),
      openCodeStartMarker: json["openCodeStartMarker"] as String?,
      openCodeExecutablePath: json["openCodeExecutablePath"] as String,
      openCodeCommand: json["openCodeCommand"] as String,
      openCodeArgs: (json["openCodeArgs"] as List<dynamic>).map((entry) => entry as String).toList(),
      port: (json["port"] as num).toInt(),
      bridgePid: (json["bridgePid"] as num).toInt(),
      bridgeStartMarker: json["bridgeStartMarker"] as String?,
      startedAt: DateTime.parse(json["startedAt"] as String),
      status: _TestStatus.values.byName(json["status"] as String),
    );
  }

  @override
  String ownerSessionIdOf({required _TestRecord record}) => record.ownerSessionId;

  @override
  int runtimePidOf({required _TestRecord record}) => record.openCodePid;

  @override
  String? runtimeStartMarkerOf({required _TestRecord record}) => record.openCodeStartMarker;

  @override
  String? runtimeExecutablePathOf({required _TestRecord record}) => record.openCodeExecutablePath;

  @override
  String runtimeCommandLineOf({required _TestRecord record}) {
    return <String>[record.openCodeCommand, ...record.openCodeArgs].join(" ");
  }

  @override
  int bridgePidOf({required _TestRecord record}) => record.bridgePid;

  @override
  String? bridgeStartMarkerOf({required _TestRecord record}) => record.bridgeStartMarker;

  @override
  _TestRecord markStopping({required _TestRecord record}) {
    return _TestRecord(
      ownerSessionId: record.ownerSessionId,
      openCodePid: record.openCodePid,
      openCodeStartMarker: record.openCodeStartMarker,
      openCodeExecutablePath: record.openCodeExecutablePath,
      openCodeCommand: record.openCodeCommand,
      openCodeArgs: record.openCodeArgs,
      port: record.port,
      bridgePid: record.bridgePid,
      bridgeStartMarker: record.bridgeStartMarker,
      startedAt: record.startedAt,
      status: _TestStatus.stopping,
    );
  }
}

class _FakeHostJsonStore implements HostJsonStore {
  final Map<String, String> files = <String, String>{};
  final List<String> calls = <String>[];

  @override
  Future<void> delete({required String name}) async {
    calls.add("delete:$name");
    files.remove(name);
  }

  @override
  Future<String?> read({required String name}) async {
    calls.add("read:$name");
    return files[name];
  }

  @override
  Future<void> quarantine({required String name, required String quarantinedName}) async {
    calls.add("quarantine:$name:$quarantinedName");
    final contents = files.remove(name);
    if (contents != null) {
      files[quarantinedName] = contents;
    }
  }

  @override
  Future<String?> update({required String name, required FutureOr<String?> Function(String? current) transform}) async {
    calls.add("update:$name");
    final updated = await transform(files[name]);
    if (updated == null) {
      files.remove(name);
    } else {
      files[name] = updated;
    }
    return updated;
  }

  @override
  Future<void> write({required String name, required String contents}) async {
    calls.add("write:$name");
    files[name] = contents;
  }
}

class _FixedClock extends ServerClock {
  const _FixedClock();

  @override
  DateTime now() => DateTime.utc(2026, 5, 15, 12, 30, 1, 234);
}
