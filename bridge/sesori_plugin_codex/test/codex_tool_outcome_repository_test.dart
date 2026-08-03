import "dart:async";
import "dart:io";

import "package:codex_plugin/src/api/codex_tool_outcome_storage.dart";
import "package:codex_plugin/src/repositories/codex_tool_outcome_repository.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("persists idempotent errors across repository instances", () async {
    final store = _MemoryHostJsonStore();
    final repository = _repository(store: store);

    await repository.recordError(sessionId: "session-2", callId: "call-2");
    await repository.recordError(sessionId: "session-1", callId: "call-1");
    await repository.recordError(sessionId: "session-1", callId: "call-1");

    final reloaded = _repository(store: store);
    expect(
      await reloaded.readStatuses(sessionId: "session-1"),
      {"call-1": PluginToolStatus.error},
    );
    expect(store.files[CodexToolOutcomeStorage.fileName], contains('"sessionId":"session-1"'));
  });

  test("deleting a session preserves other sessions", () async {
    final store = _MemoryHostJsonStore();
    final repository = _repository(store: store);
    await repository.recordError(sessionId: "session-1", callId: "call-1");
    await repository.recordError(sessionId: "session-2", callId: "call-2");

    await repository.deleteSession(sessionId: "session-1");

    expect(await repository.readStatuses(sessionId: "session-1"), isEmpty);
    expect(
      await repository.readStatuses(sessionId: "session-2"),
      {"call-2": PluginToolStatus.error},
    );
  });

  test("quarantines corrupt storage and continues empty", () async {
    final store = _MemoryHostJsonStore()..files[CodexToolOutcomeStorage.fileName] = "not-json";

    expect(
      await _repository(store: store).readStatuses(sessionId: "session-1"),
      isEmpty,
    );
    expect(store.files, isNot(contains(CodexToolOutcomeStorage.fileName)));
    expect(
      store.files.keys,
      contains("${CodexToolOutcomeStorage.fileName}.corrupt-1785758400000000"),
    );
  });

  test("quarantines an empty storage file instead of treating it as absent", () async {
    final store = _MemoryHostJsonStore()..files[CodexToolOutcomeStorage.fileName] = " \n";

    expect(
      await _repository(store: store).readStatuses(sessionId: "session-1"),
      isEmpty,
    );
    expect(store.files, isNot(contains(CodexToolOutcomeStorage.fileName)));
    expect(
      store.files.keys,
      contains("${CodexToolOutcomeStorage.fileName}.corrupt-1785758400000000"),
    );
  });

  test("surfaces storage read failures to the service layer", () async {
    final repository = _repository(store: _ReadFailingHostJsonStore());

    await expectLater(
      repository.readStatuses(sessionId: "session-1"),
      throwsA(isA<FileSystemException>()),
    );
  });
}

CodexToolOutcomeRepository _repository({required HostJsonStore store}) {
  return CodexToolOutcomeRepository(
    storage: CodexToolOutcomeStorage(
      store: store,
      clock: const _FixedClock(),
    ),
  );
}

class _FixedClock extends ServerClock {
  const _FixedClock();

  @override
  DateTime now() => DateTime.utc(2026, 8, 3, 12);
}

class _MemoryHostJsonStore implements HostJsonStore {
  final Map<String, String> files = {};

  @override
  Future<String?> read({required String name}) async => files[name];

  @override
  Future<void> write({required String name, required String contents}) async {
    files[name] = contents;
  }

  @override
  Future<void> delete({required String name}) async {
    files.remove(name);
  }

  @override
  Future<void> quarantine({
    required String name,
    required String quarantinedName,
  }) async {
    final contents = files.remove(name);
    if (contents != null) files[quarantinedName] = contents;
  }

  @override
  Future<String?> update({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  }) async {
    final contents = await transform(files[name]);
    if (contents == null) {
      files.remove(name);
    } else {
      files[name] = contents;
    }
    return contents;
  }
}

class _ReadFailingHostJsonStore extends _MemoryHostJsonStore {
  @override
  Future<String?> read({required String name}) {
    throw const FileSystemException("denied");
  }
}
