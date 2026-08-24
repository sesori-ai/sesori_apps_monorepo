import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  test("shutdown is ordered, idempotent, continues after errors, and preserves first error", () async {
    final calls = <String>[];
    final api = _Api(calls: calls)..disposeError = StateError("dispose");
    final monitor = _Monitor(calls: calls, record: "replacement")..disarmError = StateError("disarm");
    final service = _Service(calls: calls);
    final status = PluginStatusController(initial: const PluginReady());
    final plugin = _plugin(api: api, monitor: monitor, service: service, status: status, ownedRecord: "original");

    final first = plugin.shutdown(budget: null);
    final second = plugin.shutdown(budget: const Duration(seconds: 1));

    expect(identical(first, second), isTrue);
    await expectLater(first, throwsA(isA<StateError>().having((error) => error.message, "message", "disarm")));
    expect(calls, <String>["disarm", "dispose", "stop:replacement"]);
    expect(status.current, isA<PluginStopped>());
  });

  test("shutdown falls back to originally owned record", () async {
    final calls = <String>[];
    final status = PluginStatusController(initial: const PluginReady());
    final plugin = _plugin(
      api: _Api(calls: calls),
      monitor: _Monitor(calls: calls, record: null),
      service: _Service(calls: calls),
      status: status,
      ownedRecord: "original",
    );

    await plugin.shutdown(budget: null);

    expect(calls, <String>["disarm", "dispose", "stop:original"]);
  });

  test("owned-only interruption skips attached runtime and delegates for owned runtime", () async {
    final calls = <String>[];
    final api = _Api(calls: calls);
    final status = PluginStatusController(initial: const PluginReady());
    final attached = _plugin(
      api: api,
      monitor: _Monitor(calls: calls, record: null),
      service: _Service(calls: calls),
      status: status,
      ownedRecord: null,
      interruptOwnedOnly: true,
    );

    expect(await attached.interruptActiveWork(budget: Duration.zero), isEmpty);
    expect(api.interruptCount, 0);

    final owned = _plugin(
      api: api,
      monitor: _Monitor(calls: calls, record: "replacement"),
      service: _Service(calls: calls),
      status: PluginStatusController(initial: const PluginReady()),
      ownedRecord: null,
      interruptOwnedOnly: true,
    );
    await owned.interruptActiveWork(budget: Duration.zero);
    expect(api.interruptCount, 1);
  });

  test("unrestricted interruption always delegates", () async {
    final calls = <String>[];
    final api = _Api(calls: calls);
    final plugin = _plugin(
      api: api,
      monitor: _Monitor(calls: calls, record: null),
      service: _Service(calls: calls),
      status: PluginStatusController(initial: const PluginReady()),
      ownedRecord: null,
    );

    await plugin.interruptActiveWork(budget: Duration.zero);

    expect(api.interruptCount, 1);
  });
}

ManagedRuntimeBridgePlugin<String, _Api> _plugin({
  required _Api api,
  required _Monitor monitor,
  required _Service service,
  required PluginStatusController status,
  required String? ownedRecord,
  bool interruptOwnedOnly = false,
}) {
  return ManagedRuntimeBridgePlugin<String, _Api>(
    api: api,
    managedApi: api,
    reporter: ManagedRuntimeStatusReporter(
      status: status,
      clock: const _Clock(),
      degradedDebounce: Duration.zero,
    ),
    monitor: monitor,
    service: service,
    ownedRecord: ownedRecord,
    diagnostics: const PluginDiagnostics(pluginId: "test", endpoint: null, details: <String, String>{}),
    displayName: "Test",
    logContext: "test",
    interruptOwnedOnly: interruptOwnedOnly,
  );
}

class _Api({required final List<String> calls}) extends NativeProjectsPluginApi implements ManagedRuntimeApi {
  Object? disposeError;
  int interruptCount = 0;

  @override
  PluginWorkState get currentWorkState => PluginWorkState.idle;

  @override
  Stream<PluginWorkState> get workState => const Stream<PluginWorkState>.empty();

  @override
  Future<void> dispose() async {
    calls.add("dispose");
    if (disposeError case final error?) throw error;
  }

  @override
  Future<Set<String>> interruptActiveWork({required Duration budget}) async {
    interruptCount++;
    return const <String>{"session"};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Monitor({required final List<String> calls, required final String? record})
    implements ManagedRuntimeMonitor<String> {
  Object? disarmError;

  @override
  ManagedRuntimeHandle<String>? get currentHandle => record == null
      ? null
      : ManagedRuntimeHandle<String>(
          port: 1,
          record: record,
          process: null,
          identity: null,
          health: const RuntimeHealthProbe(healthy: true),
        );

  @override
  Future<void> disarm() async {
    calls.add("disarm");
    if (disarmError case final error?) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Service({required final List<String> calls}) implements ManagedProcessService<String> {
  @override
  Future<void> stopOwnedRuntime({required String record}) async {
    calls.add("stop:$record");
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class const _Clock() implements ServerClock {
  @override
  Future<void> delay({required Duration duration}) async {}

  @override
  DateTime now() => DateTime.utc(2026);
}
