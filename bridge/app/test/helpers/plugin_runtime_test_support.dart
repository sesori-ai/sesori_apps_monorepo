import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_bridge/src/bridge/runtime/plugin_generation_factory.dart";
import "package:sesori_bridge/src/bridge/runtime/plugin_runtime.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

TestPluginRuntime createTestPluginRuntime({
  required Iterable<BridgePluginApi> plugins,
  Set<String>? eligiblePluginIds,
}) {
  return TestPluginRuntime(
    plugins: {for (final plugin in plugins) plugin.id: plugin},
    eligiblePluginIds: eligiblePluginIds,
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

class TestPluginRuntime({
  required Map<String, BridgePluginApi> plugins,
  required Set<String>? eligiblePluginIds,
}) extends PluginRuntime {
  this
    : super(
        registrations: const [],
        generationFactory: const _UnusedGenerationFactory(),
        setupProcesses: const _UnusedHostProcessService(),
        environment: const {},
        clock: const ServerClock(),
        shutdownBudget: const Duration(seconds: 1),
      );

  final Map<String, BridgePluginApi> _plugins = Map<String, BridgePluginApi>.unmodifiable(plugins);
  final Set<String> _eligiblePluginIds = Set<String>.unmodifiable(eligiblePluginIds ?? plugins.keys);
  final Map<String, PluginRuntimeState> _states = {};
  final Map<String, PluginRuntimeTransition> _transitions = {};
  final StreamController<List<PluginRuntimeSnapshot>> _snapshotChanges = StreamController.broadcast(sync: true);
  final StreamController<SourcedPluginRuntimeEvent> _runtimeEvents = StreamController.broadcast(sync: true);

  /// Plugin ids that are registered but not running, so `useIfActive` reports
  /// them as unavailable while `use` would start them.
  final Set<String> stoppedPluginIds = {};
  Completer<void>? useStarted;
  Future<void>? useGate;
  bool generationCurrent = true;
  bool eventGenerationCurrent = true;
  int currentGeneration = 1;

  @override
  /// Mirrors production, where this reports only routable plugins — so a
  /// stopped one must not appear here, or a test could pass while the real
  /// runtime reports no active backend.
  Set<String> get activePluginIds =>
      Set<String>.unmodifiable(_plugins.keys.where((id) => !stoppedPluginIds.contains(id)));

  @override
  Set<String> get eligiblePluginIds => _eligiblePluginIds;

  @override
  Set<String> get startAllowedPluginIds => Set<String>.unmodifiable(_plugins.keys);

  @override
  bool isCurrentGeneration({required String pluginId, required int generation}) {
    return generationCurrent && generation == currentGeneration && _plugins.containsKey(pluginId);
  }

  @override
  bool isCurrentEventGeneration({required String pluginId, required int generation}) {
    return eventGenerationCurrent && generation == currentGeneration && _plugins.containsKey(pluginId);
  }

  @override
  bool isCurrentEvent({
    required String pluginId,
    required int generation,
    required bool allowDuringStop,
  }) {
    return isCurrentGeneration(pluginId: pluginId, generation: generation) ||
        (allowDuringStop && isCurrentEventGeneration(pluginId: pluginId, generation: generation));
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
  Stream<List<PluginRuntimeSnapshot>> get snapshots => Rx.concat([Stream.value(snapshot), _snapshotChanges.stream]);

  void emitRuntimeState({
    required String pluginId,
    required PluginRuntimeState state,
    PluginRuntimeTransition transition = PluginRuntimeTransition.none,
  }) {
    if (!_plugins.containsKey(pluginId)) throw ArgumentError.value(pluginId, "pluginId", "is not registered");
    _states[pluginId] = state;
    _transitions[pluginId] = transition;
    _snapshotChanges.add(snapshot);
  }

  @override
  Stream<SourcedPluginRuntimeEvent> get backendEvents {
    return Rx.merge([
      for (final plugin in _plugins.values)
        plugin.events.map(
          (event) => (
            pluginId: plugin.id,
            generation: currentGeneration,
            event: event,
            allowDuringStop: false,
            terminalHandoffConsumed: null,
          ),
        ),
      _runtimeEvents.stream,
    ]);
  }

  void emitRuntimeEvent({
    required String pluginId,
    required BridgeSseEvent event,
    required bool allowDuringStop,
    required Completer<void>? terminalHandoffConsumed,
  }) {
    _runtimeEvents.add((
      pluginId: pluginId,
      generation: currentGeneration,
      event: event,
      allowDuringStop: allowDuringStop,
      terminalHandoffConsumed: terminalHandoffConsumed,
    ));
  }

  @override
  Stream<SourcedPluginProvisionProgress> get provisionProgress => const Stream.empty();

  @override
  Future<void> shutdownStartedPlugins() => Future.wait([
    for (final plugin in _plugins.values) plugin.dispose(),
  ]);

  @override
  Future<void> dispose() async {
    if (!_runtimeEvents.isClosed) await _runtimeEvents.close();
    if (!_snapshotChanges.isClosed) await _snapshotChanges.close();
  }

  @override
  Future<T> use<T>({
    required String pluginId,
    required Enum operation,
    required Future<T> Function(BridgePluginApi api) body,
  }) async {
    if (useStarted case final started? when !started.isCompleted) started.complete();
    if (useGate case final gate?) await gate;
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      throw PluginOperationException(operation.name, statusCode: 503, message: "plugin $pluginId is not running");
    }
    final result = await body(plugin);
    requireCurrentGeneration(pluginId: pluginId, generation: currentGeneration, operation: operation);
    return result;
  }

  @override
  Future<({T value, int generation})> useWithGeneration<T>({
    required String pluginId,
    required Enum operation,
    required Future<T> Function(BridgePluginApi api) body,
  }) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      throw PluginOperationException(operation.name, statusCode: 503, message: "plugin $pluginId is not running");
    }
    final generation = currentGeneration;
    final value = await body(plugin);
    requireCurrentGeneration(pluginId: pluginId, generation: generation, operation: operation);
    return (value: value, generation: generation);
  }

  @override
  Future<R> useAndCommit<P, R>({
    required String pluginId,
    required Enum operation,
    required Future<P> Function(BridgePluginApi api) prepare,
    required Future<R> Function(P prepared, int generation) commit,
  }) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      throw PluginOperationException(operation.name, statusCode: 503, message: "plugin $pluginId is not running");
    }
    final prepared = await prepare(plugin);
    requireCurrentGeneration(pluginId: pluginId, generation: currentGeneration, operation: operation);
    final result = await commit(prepared, currentGeneration);
    requireCurrentGeneration(pluginId: pluginId, generation: currentGeneration, operation: operation);
    return result;
  }

  @override
  Future<R> commitCurrentGeneration<R>({
    required String pluginId,
    required int generation,
    required Enum operation,
    required Future<R> Function() commit,
  }) async {
    requireCurrentGeneration(pluginId: pluginId, generation: generation, operation: operation);
    final result = await commit();
    requireCurrentGeneration(pluginId: pluginId, generation: generation, operation: operation);
    return result;
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
    return body(plugin, currentGeneration);
  }

  @override
  Future<T?> useIfActive<T>({
    required String pluginId,
    required Enum operation,
    required Future<T> Function(BridgePluginApi api, int generation) body,
  }) async {
    // Mirrors the production guard: a registered but stopped plugin is not
    // routable, so callers that decline to start one receive null rather than
    // a live API. Without this a test could not distinguish "asked a running
    // backend" from "declined to start a stopped one".
    if (stoppedPluginIds.contains(pluginId)) return null;
    final plugin = _plugins[pluginId];
    return await (plugin == null ? null : body(plugin, currentGeneration));
  }

  PluginRuntimeSnapshot _snapshotFor(BridgePluginApi plugin) {
    return PluginRuntimeSnapshot(
      pluginId: plugin.id,
      projectOwnership: plugin is NativeProjectsPluginApi
          ? PluginProjectOwnership.native
          : PluginProjectOwnership.bridgeDerived,
      setup: const PluginSetupReady(),
      accessGate: PluginRuntimeAccessGate.enabled,
      startAllowed: true,
      generation: currentGeneration,
      state: _states[plugin.id] ?? PluginRuntimeState.active,
      workState: PluginWorkState.idle,
      leaseCount: 0,
      transition: _transitions[plugin.id] ?? PluginRuntimeTransition.none,
    );
  }
}

class _AlwaysCurrentTestPluginRuntime() extends TestPluginRuntime {
  this : super(plugins: const {}, eligiblePluginIds: null);

  @override
  bool isCurrentGeneration({required String pluginId, required int generation}) => generation == 1;

  @override
  bool isCurrentEventGeneration({required String pluginId, required int generation}) => generation == 1;

  @override
  bool isCurrentEvent({
    required String pluginId,
    required int generation,
    required bool allowDuringStop,
  }) => generation == 1;
}

class const _UnusedGenerationFactory() implements PluginGenerationFactory {
  @override
  Future<void> enforceBridgeOwnership() async {}

  @override
  Stream<PluginGenerationStartEvent> start({
    required PluginRuntimeRegistration registration,
    required StartAbortSignal startAborted,
  }) => throw UnsupportedError("test runtime is already active");
}

class const _TestDescriptor({@override required final String id}) extends BridgePluginDescriptor {
  @override
  String get displayName => id;

  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.bridgeDerived;

  @override
  PluginSessionOptionsScope get sessionOptionsScope => PluginSessionOptionsScope.project;

  @override
  List<PluginOption> get options => const [];

  @override
  Future<BridgePlugin> start(PluginHost host) => throw UnsupportedError("unused");
}

class const _UnusedHostProcessService() implements HostProcessService {
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
