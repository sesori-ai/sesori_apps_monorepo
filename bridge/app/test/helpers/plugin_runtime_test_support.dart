import "package:rxdart/rxdart.dart";
import "package:sesori_bridge/src/bridge/runtime/plugin_generation_factory.dart";
import "package:sesori_bridge/src/bridge/runtime/plugin_runtime.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

TestPluginRuntime createTestPluginRuntime({
  required Iterable<BridgePluginApi> plugins,
  Map<String, PluginSetupStatus> setupByPluginId = const {},
}) {
  return TestPluginRuntime(
    plugins: {for (final plugin in plugins) plugin.id: plugin},
    setupByPluginId: setupByPluginId,
  );
}

PluginRuntime createAlwaysCurrentTestPluginRuntime() => _AlwaysCurrentTestPluginRuntime();

PluginRuntime createRegisteredTestPluginRuntime({required Iterable<String> pluginIds}) {
  return PluginRuntime(
    registrations: [
      for (final pluginId in pluginIds)
        PluginRuntimeRegistration(
          descriptor: _TestDescriptor(id: pluginId),
          config: const PluginConfig(values: {}),
          stateDirectory: ".",
        ),
    ],
    generationFactory: const _UnusedGenerationFactory(),
    setupProcesses: const _UnusedHostProcessService(),
    environment: const {},
    clock: const ServerClock(),
    shutdownBudget: const Duration(seconds: 1),
  );
}

class TestPluginRuntime extends PluginRuntime {
  TestPluginRuntime({
    required Map<String, BridgePluginApi> plugins,
    Map<String, PluginSetupStatus> setupByPluginId = const {},
  })
    : _plugins = Map<String, BridgePluginApi>.unmodifiable(plugins),
      _setupByPluginId = Map<String, PluginSetupStatus>.unmodifiable(setupByPluginId),
      super(
        registrations: const [],
        generationFactory: const _UnusedGenerationFactory(),
        setupProcesses: const _UnusedHostProcessService(),
        environment: const {},
        clock: const ServerClock(),
        shutdownBudget: const Duration(seconds: 1),
      );

  final Map<String, BridgePluginApi> _plugins;
  final Map<String, PluginSetupStatus> _setupByPluginId;
  bool generationCurrent = true;

  @override
  Set<String> get activePluginIds => Set<String>.unmodifiable(
    _plugins.keys.where((pluginId) => (_setupByPluginId[pluginId] ?? const PluginSetupReady()) is PluginSetupReady),
  );

  @override
  Set<String> get startAllowedPluginIds => activePluginIds;

  @override
  bool isCurrentGeneration({required String pluginId, required int generation}) {
    return generationCurrent && generation == 1 && _plugins.containsKey(pluginId);
  }

  @override
  void requireCurrentGeneration({
    required String pluginId,
    required int generation,
    required Enum operation,
  }) {
    if (!isCurrentGeneration(pluginId: pluginId, generation: generation)) {
      throw PluginOperationException(
        operation.name,
        statusCode: 503,
        message: "plugin generation changed during operation",
      );
    }
  }

  @override
  void applyAccess({required List<PluginRuntimeAccess> entries}) {}

  @override
  List<PluginRuntimeSnapshot> get snapshot => [
    for (final plugin in _plugins.values) _snapshotFor(plugin),
  ];

  @override
  Stream<List<PluginRuntimeSnapshot>> get snapshots => Stream.value(snapshot);

  @override
  Stream<SourcedPluginRuntimeEvent> get backendEvents {
    return Rx.merge([
      for (final plugin in _plugins.values)
        plugin.events.map((event) => (pluginId: plugin.id, generation: 1, event: event)),
    ]);
  }

  @override
  Stream<SourcedPluginProvisionProgress> get provisionProgress => const Stream.empty();

  @override
  Future<void> disposeStartedApis() => Future.wait([
    for (final plugin in _plugins.values) plugin.dispose(),
  ]);

  @override
  Future<void> dispose() async {}

  @override
  Future<T> use<T>({
    required String pluginId,
    required Enum operation,
    required Future<T> Function(BridgePluginApi api) body,
  }) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      throw PluginOperationException(operation.name, statusCode: 503, message: "plugin $pluginId is not running");
    }
    return body(plugin);
  }

  @override
  Stream<T> useStream<T>({
    required String pluginId,
    required Enum operation,
    required Stream<T> Function(BridgePluginApi api, int generation) body,
  }) {
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      return Stream.error(
        PluginOperationException(operation.name, statusCode: 503, message: "plugin $pluginId is not running"),
      );
    }
    return body(plugin, 1);
  }

  @override
  Future<T?> useIfActive<T>({
    required String pluginId,
    required Enum operation,
    required Future<T> Function(BridgePluginApi api, int generation) body,
  }) async {
    final plugin = _plugins[pluginId];
    return plugin == null ? null : body(plugin, 1);
  }

  PluginRuntimeSnapshot _snapshotFor(BridgePluginApi plugin) {
    final setup = _setupByPluginId[plugin.id] ?? const PluginSetupReady();
    final setupReady = setup is PluginSetupReady;
    return PluginRuntimeSnapshot(
      pluginId: plugin.id,
      projectOwnership: plugin is NativeProjectsPluginApi
          ? PluginProjectOwnership.native
          : PluginProjectOwnership.bridgeDerived,
      setup: setup,
      accessGate: PluginRuntimeAccessGate.enabled,
      startAllowed: setupReady,
      generation: 1,
      state: setupReady ? PluginRuntimeState.active : PluginRuntimeState.blocked,
      workState: PluginWorkState.idle,
      leaseCount: 0,
      transition: PluginRuntimeTransition.none,
    );
  }
}

class _AlwaysCurrentTestPluginRuntime extends TestPluginRuntime {
  _AlwaysCurrentTestPluginRuntime() : super(plugins: const {});

  @override
  bool isCurrentGeneration({required String pluginId, required int generation}) => generation == 1;
}

class _UnusedGenerationFactory implements PluginGenerationFactory {
  const _UnusedGenerationFactory();

  @override
  Future<void> enforceBridgeOwnership() async {}

  @override
  Stream<PluginGenerationStartEvent> start({
    required PluginRuntimeRegistration registration,
    required StartAbortSignal startAborted,
  }) => throw UnsupportedError("test runtime is already active");
}

class _TestDescriptor extends BridgePluginDescriptor {
  const _TestDescriptor({required this.id});

  @override
  final String id;

  @override
  String get displayName => id;

  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.bridgeDerived;

  @override
  List<PluginOption> get options => const [];

  @override
  Future<BridgePlugin> start(PluginHost host) => throw UnsupportedError("unused");
}

class _UnusedHostProcessService implements HostProcessService {
  const _UnusedHostProcessService();

  @override
  Future<ProcessIdentity?> inspect({required int pid}) => throw UnsupportedError("unused");

  @override
  Future<SignalResult> signalForce({required int pid}) => throw UnsupportedError("unused");

  @override
  Future<SignalResult> signalGraceful({required int pid}) => throw UnsupportedError("unused");

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) => throw UnsupportedError("unused");
}
