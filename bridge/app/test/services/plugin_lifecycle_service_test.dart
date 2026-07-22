import "dart:async";
import "dart:io";

import "package:rxdart/rxdart.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const shutdownBudget = Duration(seconds: 1);

  PluginLifecycleService createService() {
    return PluginLifecycleService()
      ..registerPlugins(
        plugins: const [
          (id: "one", displayName: "One"),
          (id: "two", displayName: "Two"),
          (id: "known-disabled", displayName: "Known Disabled"),
        ],
      )
      ..initialize(
        disabledPluginIds: const {"known-disabled"},
        setupById: const {
          "one": PluginSetupReady(),
          "two": PluginSetupReady(),
          "known-disabled": PluginSetupNotInspected(),
        },
      );
  }

  test("publishes ordered selection and isolates unavailable plugins", () {
    final service = createService()..registerUnavailable(id: "two");

    expect(service.compositionView.knownPluginIds, {"one", "two", "known-disabled"});
    expect(service.compositionView.enabledPluginIds, ["one", "two"]);
    expect(
      service.compositionView.defaultEnabledPluginId,
      isNull,
      reason: "a default is routable only after a plugin starts successfully",
    );
    expect(service.metadataSnapshot.map((plugin) => plugin.id), ["one", "two"]);
    expect(service.metadataSnapshot.last.state, PluginLifecycleState.unavailable);
    expect(service.metadataSnapshot.last.actionHint, isNot(contains("descriptor-secret")));
  });

  test("eligibility follows the denylist and ordering follows display name", () async {
    final service = PluginLifecycleService()
      ..registerPlugins(
        plugins: const [
          (id: "blocked", displayName: "Blocked"),
          (id: "two", displayName: "Two"),
          (id: "one", displayName: "One"),
        ],
      );
    addTearDown(service.dispose);

    final selection = service.initialize(
      disabledPluginIds: const {},
      setupById: const {
        "blocked": PluginSetupAuthenticationRequired(actionHint: "Authenticate this plugin."),
        "two": PluginSetupReady(),
        "one": PluginSetupReady(),
      },
    );

    expect(selection.enabledPluginIds, ["blocked", "one", "two"]);
    expect(selection.eagerPluginIds, ["one", "two"]);
    expect(selection.defaultPluginId, "one");
    expect(service.metadataSnapshot.map((plugin) => plugin.id), ["blocked", "one", "two"]);
    expect(service.selectableMetadataSnapshot, isEmpty, reason: "choices are published only after startup succeeds");
    expect(service.setupSnapshot.plugins.map((plugin) => plugin.id), ["blocked", "one", "two"]);
    expect(service.setupSnapshot.plugins.first.state, PluginSetupState.authenticationRequired);
  });

  test("denied plugins remain visible as not inspected but are not eligible", () async {
    final service = PluginLifecycleService()
      ..registerPlugins(
        plugins: const [
          (id: "cursor", displayName: "Cursor"),
          (id: "opencode", displayName: "OpenCode"),
        ],
      );
    addTearDown(service.dispose);

    final selection = service.initialize(
      disabledPluginIds: const {"cursor", "future-plugin"},
      setupById: const {
        "opencode": PluginSetupReady(),
        "cursor": PluginSetupNotInspected(),
      },
    );

    expect(selection.enabledPluginIds, ["opencode"]);
    expect(selection.eagerPluginIds, ["opencode"]);
    expect(selection.defaultPluginId, "opencode");
    expect(service.setupSnapshot.plugins.first.state, PluginSetupState.notInspected);
  });

  test("supports a zero-routable-plugin bridge when no setup is usable", () async {
    final service = PluginLifecycleService()
      ..registerPlugins(
        plugins: const [
          (id: "opencode", displayName: "OpenCode"),
          (id: "cursor", displayName: "Cursor"),
        ],
      );
    addTearDown(service.dispose);

    final selection = service.initialize(
      disabledPluginIds: const {},
      setupById: const {
        "opencode": PluginSetupRuntimeMissing(actionHint: "Fix OpenCode."),
        "cursor": PluginSetupUnknown(actionHint: "Retry Cursor setup detection."),
      },
    );

    expect(selection.enabledPluginIds, ["cursor", "opencode"]);
    expect(selection.eagerPluginIds, isEmpty);
    expect(selection.defaultPluginId, isNull);
    expect(service.compositionView.enabledPluginIds, ["cursor", "opencode"]);
    expect(service.compositionView.defaultEnabledPluginId, isNull);
    expect(service.compositionView.operationalPlugins, isEmpty);
    expect(service.metadataSnapshot, hasLength(2));
    expect(service.setupSnapshot.plugins, hasLength(2));
  });

  test("post-start terminal failure is logged locally and omitted from metadata", () async {
    final service = createService();
    final plugin = _FakeLifecyclePlugin(id: "one", status: const PluginStarting());
    final originalLevel = Log.level;
    addTearDown(() {
      Log.level = originalLevel;
    });
    Log.level = LogLevel.debug;
    final logs = <String>[];

    await IOOverrides.runZoned(
      () async {
        await service.registerStart(
          id: "one",
          startFuture: Future.value(plugin),
          shutdownBudget: shutdownBudget,
        );
        expect(service.compositionView.operationalPlugins["one"], same(plugin.api));
        expect(service.metadataSnapshot.first.state, PluginLifecycleState.ready);
        plugin.publish(PluginFailed(reason: "raw failure secret", cause: StateError("socket closed")));
        await Future<void>.delayed(Duration.zero);
      },
      stderr: () => _CapturingStdout(logs),
    );
    expect(service.compositionView.operationalPlugins, isNot(contains("one")));
    expect(service.metadataSnapshot.first.state, PluginLifecycleState.failed);
    expect(service.selectableMetadataSnapshot, isEmpty);
    expect(service.metadataSnapshot.first.actionHint, isNot(contains("raw failure secret")));
    expect(logs.join("\n"), allOf(contains('Plugin "one"'), contains("raw failure secret"), contains("socket closed")));
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

  test("composition and plugin discovery share the first routable default", () async {
    final service = createService();
    final wrong = _FakeLifecyclePlugin(id: "wrong", status: const PluginReady());
    final two = _FakeLifecyclePlugin(id: "two", status: const PluginReady());

    await Future.wait([
      service.registerStart(
        id: "one",
        startFuture: Future.value(wrong),
        shutdownBudget: shutdownBudget,
      ),
      service.registerStart(
        id: "two",
        startFuture: Future.value(two),
        shutdownBudget: shutdownBudget,
      ),
    ]);

    expect(service.compositionView.defaultEnabledPluginId, "two");
    expect(service.selectableMetadataSnapshot.map((plugin) => plugin.id), ["two"]);
    expect(service.selectableMetadataSnapshot.single.isDefault, isTrue);
    await service.dispose();
  });

  test("ordinary start failure is logged with its plugin id and omitted from metadata", () async {
    final service = createService();
    final originalLevel = Log.level;
    addTearDown(() {
      Log.level = originalLevel;
    });
    Log.level = LogLevel.debug;
    final logs = <String>[];

    await IOOverrides.runZoned(
      () => service.registerStart(
        id: "one",
        startFuture: Future<BridgePlugin>.error(
          const PluginStartException("no runnable binary", cause: null),
        ),
        shutdownBudget: shutdownBudget,
      ),
      stderr: () => _CapturingStdout(logs),
    );

    expect(logs.join("\n"), allOf(contains('Plugin "one"'), contains("no runnable binary")));
    expect(service.metadataSnapshot.first.state, PluginLifecycleState.failed);
    expect(service.metadataSnapshot.first.actionHint, isNot(contains("no runnable binary")));
    await service.dispose();
  });

  test("API disposal catches a late API returned after the plugin-dispose phase begins", () async {
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

  test("API disposal does not wait for a blocked start before disposing returned APIs", () async {
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

class _CapturingStdout implements Stdout {
  _CapturingStdout(this.lines);

  final List<String> lines;

  @override
  void writeln([Object? object = ""]) {
    lines.add(object.toString());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
