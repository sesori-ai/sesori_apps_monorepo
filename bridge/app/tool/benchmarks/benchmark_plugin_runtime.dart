import "package:rxdart/rxdart.dart";
import "package:sesori_bridge/src/bridge/runtime/plugin_generation_factory.dart";
import "package:sesori_bridge/src/bridge/runtime/plugin_runtime.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

BenchmarkPluginRuntime createBenchmarkPluginRuntime({required Iterable<BridgePluginApi> plugins}) {
  final pluginList = plugins.toList(growable: false);
  final pluginIds = pluginList.map((plugin) => plugin.id).toList(growable: false);
  if (pluginIds.toSet().length != pluginIds.length) {
    throw ArgumentError.value(plugins, "plugins", "must not contain duplicate plugin ids");
  }
  return BenchmarkPluginRuntime(plugins: {for (final plugin in pluginList) plugin.id: plugin});
}

class BenchmarkPluginRuntime extends PluginRuntime {
  BenchmarkPluginRuntime({required Map<String, BridgePluginApi> plugins})
    : _plugins = Map<String, BridgePluginApi>.unmodifiable(plugins),
      super(
        registrations: const [],
        generationFactory: const _UnusedGenerationFactory(),
        setupProcesses: const _UnusedHostProcessService(),
        environment: const {},
        clock: const ServerClock(),
        shutdownBudget: const Duration(seconds: 1),
      );

  final Map<String, BridgePluginApi> _plugins;

  @override
  Set<String> get activePluginIds => Set<String>.unmodifiable(_plugins.keys);

  @override
  Set<String> get eligiblePluginIds => Set<String>.unmodifiable(_plugins.keys);

  @override
  Set<String> get startAllowedPluginIds => Set<String>.unmodifiable(_plugins.keys);

  @override
  List<PluginRuntimeSnapshot> get snapshot => [
    for (final plugin in _plugins.values)
      PluginRuntimeSnapshot(
        pluginId: plugin.id,
        projectOwnership: plugin is NativeProjectsPluginApi
            ? PluginProjectOwnership.native
            : PluginProjectOwnership.bridgeDerived,
        setup: const PluginSetupReady(),
        eligible: true,
        startAllowed: true,
        generation: 1,
        state: PluginRuntimeState.active,
        leaseCount: 0,
        transition: PluginRuntimeTransition.none,
      ),
  ];

  @override
  Stream<List<PluginRuntimeSnapshot>> get snapshots => Stream.value(snapshot);

  @override
  Stream<SourcedPluginRuntimeEvent> get backendEvents => Rx.merge([
    for (final plugin in _plugins.values)
      plugin.events.map((event) => (pluginId: plugin.id, generation: 1, event: event)),
  ]);

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
  Future<R> useAndCommit<P, R>({
    required String pluginId,
    required Enum operation,
    required Future<P> Function(BridgePluginApi api) prepare,
    required Future<R> Function(P prepared) commit,
  }) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      throw PluginOperationException(operation.name, statusCode: 503, message: "plugin $pluginId is not running");
    }
    return commit(await prepare(plugin));
  }

  @override
  Future<R> commitCurrentGeneration<R>({
    required String pluginId,
    required int generation,
    required Enum operation,
    required Future<R> Function() commit,
  }) {
    if (!isCurrentGeneration(pluginId: pluginId, generation: generation)) {
      throw PluginOperationException(operation.name, statusCode: 503);
    }
    return commit();
  }

  @override
  Stream<T> useStream<T>({
    required String pluginId,
    required Enum operation,
    required Stream<T> Function(BridgePluginApi api, int generation) body,
  }) {
    final plugin = _plugins[pluginId];
    return plugin == null ? Stream.error(PluginOperationException(operation.name, statusCode: 503)) : body(plugin, 1);
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

  @override
  bool isCurrentGeneration({required String pluginId, required int generation}) {
    return generation == 1 && _plugins.containsKey(pluginId);
  }
}

class _UnusedGenerationFactory implements PluginGenerationFactory {
  const _UnusedGenerationFactory();

  @override
  Future<void> enforceBridgeOwnership() async {}

  @override
  Stream<PluginGenerationStartEvent> start({
    required PluginRuntimeRegistration registration,
    required StartAbortSignal startAborted,
  }) => throw UnsupportedError("benchmark runtime is already active");
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
