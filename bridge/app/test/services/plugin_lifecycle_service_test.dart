import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const shutdownBudget = Duration(seconds: 1);

  PluginLifecycleService createService() {
    return PluginLifecycleService()..registerSelection(
      knownPluginIds: {"one", "two", "known-disabled"},
      enabledPlugins: const [
        (id: "one", displayName: "One", isDefault: true),
        (id: "two", displayName: "Two", isDefault: false),
      ],
    );
  }

  test("publishes ordered selection and isolates unavailable plugins", () {
    final service = createService()..registerUnavailable(id: "two");

    expect(service.compositionView.knownPluginIds, {"one", "two", "known-disabled"});
    expect(service.compositionView.enabledPluginIds, ["one", "two"]);
    expect(service.compositionView.defaultEnabledPluginId, "one");
    expect(service.metadataSnapshot.map((plugin) => plugin.id), ["one", "two"]);
    expect(service.metadataSnapshot.last.state, PluginLifecycleState.unavailable);
    expect(service.metadataSnapshot.last.actionHint, isNot(contains("descriptor-secret")));
  });

  test("registerStart settles after starting API and metadata are published", () async {
    final service = createService();
    final plugin = _FakeLifecyclePlugin(id: "one", status: const PluginStarting());

    await service.registerStart(
      id: "one",
      startFuture: Future.value(plugin),
      shutdownBudget: shutdownBudget,
    );

    expect(service.compositionView.operationalPlugins["one"], same(plugin.api));
    expect(service.metadataSnapshot.first.state, PluginLifecycleState.ready);
    plugin.publish(const PluginFailed(reason: "raw failure secret", cause: null));
    await Future<void>.delayed(Duration.zero);
    expect(service.compositionView.operationalPlugins, isNot(contains("one")));
    expect(service.metadataSnapshot.first.state, PluginLifecycleState.failed);
    expect(service.metadataSnapshot.first.actionHint, isNot(contains("raw failure secret")));
    await service.dispose();
  });

  test("identity mismatch is retained for shutdown but never routed", () async {
    final service = createService();
    final plugin = _FakeLifecyclePlugin(id: "wrong", status: const PluginReady());

    await service.registerStart(
      id: "one",
      startFuture: Future.value(plugin),
      shutdownBudget: shutdownBudget,
    );

    expect(service.compositionView.operationalPlugins, isNot(contains("one")));
    expect(service.metadataSnapshot.first.state, PluginLifecycleState.failed);
    await service.disposeStartedApis();
    expect(plugin.apiImpl.disposeCalls, 1);
    await service.dispose();
    expect(plugin.shutdownCalls, 1);
  });

  test("early disposal catches an API returned after shutdown begins", () async {
    final service = createService();
    final start = Completer<BridgePlugin>();
    final plugin = _FakeLifecyclePlugin(id: "one", status: const PluginReady());
    final settlement = service.registerStart(
      id: "one",
      startFuture: start.future,
      shutdownBudget: shutdownBudget,
    );

    final disposal = service.disposeStartedApis();
    start.complete(plugin);
    await Future.wait([settlement, disposal]);

    expect(plugin.apiImpl.disposeCalls, 1);
    await service.dispose();
  });

  test("early disposal does not wait for a blocked start before disposing returned APIs", () async {
    final service = createService();
    final one = _FakeLifecyclePlugin(id: "one", status: const PluginReady());
    final twoStart = Completer<BridgePlugin>();
    await service.registerStart(
      id: "one",
      startFuture: Future.value(one),
      shutdownBudget: shutdownBudget,
    );
    final twoSettlement = service.registerStart(
      id: "two",
      startFuture: twoStart.future,
      shutdownBudget: shutdownBudget,
    );

    final disposal = service.disposeStartedApis();
    await Future<void>.delayed(Duration.zero);

    expect(one.apiImpl.disposeCalls, 1);
    final two = _FakeLifecyclePlugin(id: "two", status: const PluginReady());
    twoStart.complete(two);
    await Future.wait([twoSettlement, disposal]);
    expect(two.apiImpl.disposeCalls, 1);
    await service.dispose();
  });

  test("stopAll launches plugin shutdowns concurrently and attempts every plugin", () async {
    final service = createService();
    final oneGate = Completer<void>();
    final twoGate = Completer<void>();
    final one = _FakeLifecyclePlugin(id: "one", status: const PluginReady(), shutdownGate: oneGate);
    final two = _FakeLifecyclePlugin(id: "two", status: const PluginReady(), shutdownGate: twoGate);
    await Future.wait([
      service.registerStart(id: "one", startFuture: Future.value(one), shutdownBudget: shutdownBudget),
      service.registerStart(id: "two", startFuture: Future.value(two), shutdownBudget: shutdownBudget),
    ]);

    final stop = service.stopAll();
    await Future<void>.delayed(Duration.zero);
    expect(one.shutdownCalls, 1);
    expect(two.shutdownCalls, 1);
    oneGate.complete();
    twoGate.complete();
    await stop;
    await service.dispose();
  });
}

class _FakeLifecyclePlugin implements BridgePlugin {
  _FakeLifecyclePlugin({
    required String id,
    required PluginStatus status,
    this.shutdownGate,
  }) : apiImpl = _FakePluginApi(id),
       _statuses = BehaviorSubject<PluginStatus>.seeded(status);

  final _FakePluginApi apiImpl;
  final BehaviorSubject<PluginStatus> _statuses;
  final Completer<void>? shutdownGate;
  int shutdownCalls = 0;

  void publish(PluginStatus status) => _statuses.add(status);

  @override
  BridgePluginApi get api => apiImpl;

  @override
  PluginStatus get currentStatus => _statuses.value;

  @override
  Stream<PluginStatus> get status => _statuses.stream;

  @override
  PluginDiagnostics describe() => PluginDiagnostics(pluginId: apiImpl.id, endpoint: null, details: const {});

  @override
  Future<void> shutdown({required Duration? budget}) async {
    shutdownCalls++;
    await shutdownGate?.future;
    await _statuses.close();
  }
}

class _FakePluginApi extends NativeProjectsPluginApi {
  _FakePluginApi(this.id);

  @override
  final String id;
  int disposeCalls = 0;

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
