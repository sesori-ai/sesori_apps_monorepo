import "package:opencode_plugin/src/runtime/open_code_bridge_plugin.dart";
import "package:opencode_plugin/src/runtime/open_code_managed_api.dart";
import "package:opencode_plugin/src/runtime/open_code_ownership_record.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart"
    show ManagedProcessService, ManagedRuntimeHandle, ManagedRuntimeMonitor;
import "package:test/test.dart";

void main() {
  group("OpenCodeBridgePlugin.shutdown teardown errors", () {
    late PluginStatusController status;
    late _FakeApi api;
    late _FakeMonitor monitor;
    late _FakeService service;

    OpenCodeBridgePlugin plugin() {
      status = PluginStatusController(initial: const PluginReady());
      return OpenCodeBridgePlugin(
        api: api,
        reporter: OpenCodeRuntimeStatusReporter(status: status, clock: const _ImmediateClock()),
        monitor: monitor,
        service: service,
        ownedRecord: _record(),
        port: 51000,
        serverUrl: "http://127.0.0.1:51000",
      );
    }

    setUp(() {
      api = _FakeApi();
      monitor = _FakeMonitor();
      service = _FakeService();
    });

    test("a disarm failure still runs the remaining teardown steps and surfaces as the shutdown error", () async {
      monitor.disarmError = StateError("disarm failed");

      await expectLater(
        plugin().shutdown(budget: null),
        throwsA(isA<StateError>().having((e) => e.message, "message", "disarm failed")),
      );

      expect(api.disposeCount, equals(1));
      expect(service.stoppedRecords, hasLength(1));
      expect(status.current, isA<PluginStopped>());
    });

    test("a disarm failure is the primary teardown error when later steps also fail", () async {
      monitor.disarmError = StateError("disarm failed");
      api.disposeError = StateError("dispose failed");

      await expectLater(
        plugin().shutdown(budget: null),
        throwsA(isA<StateError>().having((e) => e.message, "message", "disarm failed")),
      );

      expect(service.stoppedRecords, hasLength(1));
      expect(status.current, isA<PluginStopped>());
    });
  });
}

OpenCodeOwnershipRecord _record() {
  return OpenCodeOwnershipRecord(
    ownerSessionId: "owner-current",
    openCodePid: 4242,
    openCodeStartMarker: null,
    openCodeExecutablePath: "/bin/opencode",
    openCodeCommand: "/bin/opencode",
    openCodeArgs: const <String>["serve"],
    port: 51000,
    bridgePid: 900,
    bridgeStartMarker: null,
    startedAt: DateTime.utc(2026, 6, 1),
    status: OpenCodeOwnershipStatus.ready,
  );
}

class _ImmediateClock implements ServerClock {
  const _ImmediateClock();

  @override
  DateTime now() => DateTime.utc(2026, 6, 1, 12);

  @override
  Future<void> delay({required Duration duration}) async {}
}

class _FakeApi implements OpenCodeManagedApi {
  int disposeCount = 0;
  Object? disposeError;

  @override
  PluginWorkState get currentWorkState => PluginWorkState.idle;

  @override
  Stream<PluginWorkState> get workState => Stream<PluginWorkState>.multi(
    (listener) => listener.add(PluginWorkState.idle),
    isBroadcast: true,
  );

  @override
  Future<void> dispose() async {
    disposeCount += 1;
    final error = disposeError;
    if (error != null) {
      throw error;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMonitor implements ManagedRuntimeMonitor<OpenCodeOwnershipRecord> {
  Object? disarmError;
  int disarmCount = 0;

  @override
  ManagedRuntimeHandle<OpenCodeOwnershipRecord>? get currentHandle => null;

  @override
  Future<void> disarm() async {
    disarmCount += 1;
    final error = disarmError;
    if (error != null) {
      throw error;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeService implements ManagedProcessService<OpenCodeOwnershipRecord> {
  final List<OpenCodeOwnershipRecord> stoppedRecords = <OpenCodeOwnershipRecord>[];

  @override
  Future<void> stopOwnedRuntime({required OpenCodeOwnershipRecord record}) async {
    stoppedRecords.add(record);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
