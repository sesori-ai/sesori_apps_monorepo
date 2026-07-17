import "dart:async";
import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge/src/bridge/runtime/bridge_runtime_runner.dart";
import "package:sesori_bridge/src/server/api/runtime_file_api.dart";
import "package:sesori_bridge/src/server/repositories/process_repository.dart";
import "package:sesori_bridge/src/server/repositories/startup_mutex_repository.dart";
import "package:sesori_bridge/src/server/services/bridge_instance_service.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_bridge/src/updater/models/managed_runtime_paths.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

Future<void> main(List<String> args) async {
  final selectedCount = _readInt(args: args, name: "plugins", fallback: 1);
  final warmupCount = _readInt(args: args, name: "warmup", fallback: 3);
  final sampleCount = _readInt(args: args, name: "samples", fallback: 20);
  if (![1, 3, 8].contains(selectedCount)) {
    throw ArgumentError.value(selectedCount, "plugins", "must be 1, 3, or 8");
  }
  if (warmupCount < 0) {
    throw const FormatException("--warmup must be a non-negative integer");
  }
  if (sampleCount < 1) {
    throw const FormatException("--samples must be a positive integer");
  }

  for (var index = 0; index < warmupCount; index++) {
    await _runFixture(selectedCount: selectedCount);
  }
  final samples = <_StartupSample>[];
  for (var index = 0; index < sampleCount; index++) {
    samples.add(await _runFixture(selectedCount: selectedCount));
  }

  final totalMicros = [for (final sample in samples) sample.totalMicros]..sort();
  final firstOperationalMicros = [for (final sample in samples) sample.firstOperationalMicros]..sort();
  final perPlugin = <String, List<int>>{};
  for (final sample in samples) {
    for (final entry in sample.startMicros.entries) {
      (perPlugin[entry.key] ??= <int>[]).add(entry.value);
    }
  }

  stdout.writeln(
    jsonEncode({
      "schemaVersion": 1,
      "benchmark": "multi_plugin_startup",
      "commit": Platform.environment["GIT_COMMIT"] ?? "working-tree",
      "os": Platform.operatingSystem,
      "osVersion": Platform.operatingSystemVersion,
      "cpu": Platform.environment["PROCESSOR_IDENTIFIER"] ?? Platform.environment["HOSTTYPE"] ?? "unknown",
      "warmupCount": warmupCount,
      "sampleCount": sampleCount,
      "selectedCount": selectedCount,
      "totalStartupMicros": _percentiles(totalMicros),
      "firstOperationalMicros": _percentiles(firstOperationalMicros),
      "perPluginStartMicros": {
        for (final entry in perPlugin.entries) entry.key: _percentiles(entry.value..sort()),
      },
      "maximumConcurrentStarts": samples.map((sample) => sample.maximumConcurrentStarts).reduce(_max),
      "mutexAcquisitionCount": samples.map((sample) => sample.mutexAcquisitionCount).toSet().single,
      "singletonEnforcementCount": samples.map((sample) => sample.singletonEnforcementCount).toSet().single,
      "stateDirectories": samples.last.stateDirectories,
      "provisioningOrder": samples.last.provisioningOrder,
    }),
  );
}

Future<_StartupSample> _runFixture({required int selectedCount}) async {
  final runtimeDirectory = await Directory.systemTemp.createTemp(
    "sesori-multi-plugin-startup-benchmark-$selectedCount-",
  );

  final stopwatch = Stopwatch()..start();
  final probe = _StartupProbe(stopwatch: stopwatch);
  final descriptors = [
    for (var index = 0; index < selectedCount; index++) _FakeDescriptor(id: "plugin-$index", probe: probe),
  ];
  final lifecycle = PluginLifecycleService()
    ..registerSelection(
      knownPluginIds: {for (final descriptor in descriptors) descriptor.id},
      enabledPlugins: [
        for (var index = 0; index < descriptors.length; index++)
          (id: descriptors[index].id, displayName: descriptors[index].displayName, isDefault: index == 0),
      ],
    );
  final startupMutexRepository = _FakeStartupMutexRepository();
  final bridgeInstanceService = _FakeBridgeInstanceService();
  final startedPlugins = <String, BridgePlugin>{};

  try {
    await BridgeRuntimeRunner.startPluginsUnderStartupMutex(
      descriptors: descriptors,
      pluginConfigs: {
        for (final descriptor in descriptors) descriptor.id: const PluginConfig(values: <String, Object?>{}),
      },
      lifecycleService: lifecycle,
      startedPlugins: startedPlugins,
      managedRuntimePaths: ManagedRuntimePaths(
        installRoot: runtimeDirectory.path,
        binaryPath: p.join(runtimeDirectory.path, "bin", "sesori-bridge"),
        cacheDirectory: runtimeDirectory.path,
      ),
      currentBridgeIdentity: ProcessIdentity(
        pid: 1,
        startMarker: "benchmark",
        executablePath: "/fixture/sesori-bridge",
        commandLine: "/fixture/sesori-bridge",
        ownerUser: null,
        platform: Platform.operatingSystem,
        capturedAt: DateTime.utc(2026, 7, 17),
      ),
      ownerSessionId: "benchmark-owner",
      startupMutexRepository: startupMutexRepository,
      bridgeInstanceService: bridgeInstanceService,
      processRepository: _FakeProcessRepository(),
      runtimeFileApi: RuntimeFileApi(runtimeDirectory: runtimeDirectory.path),
      serverClock: const ServerClock(),
      environment: const <String, String>{},
      currentUser: null,
      startAborted: StartAbortSignal.never,
      provisionNotifier: null,
    );
    final totalMicros = stopwatch.elapsedMicroseconds;

    if (startupMutexRepository.acquisitionCount != 1 || bridgeInstanceService.enforcementCount != 1) {
      throw StateError("startup fixture did not use one mutex/enforcement");
    }
    if (probe.stateDirectories.toSet().length != selectedCount) {
      throw StateError("plugin state directories are not unique");
    }
    final expectedStateDirectories = [
      for (final descriptor in descriptors) p.join(runtimeDirectory.path, "plugins", descriptor.id),
    ];
    if (!_equalLists(probe.stateDirectories, expectedStateDirectories)) {
      throw StateError("plugin state directories did not come from the production host composition");
    }
    if (!_equalLists(probe.provisioningOrder, descriptors.map((descriptor) => descriptor.id).toList())) {
      throw StateError("provisioning order changed");
    }
    final expectedOperations = [
      for (final descriptor in descriptors) ...[
        "provision:${descriptor.id}",
        "ready:${descriptor.id}",
        "start:${descriptor.id}",
      ],
    ];
    if (!_equalLists(probe.operations, expectedOperations)) {
      throw StateError("a plugin was not launched immediately after its provisioning phase");
    }
    if (selectedCount > 1 && probe.maximumConcurrentStarts < 2) {
      throw StateError("plugin starts did not overlap");
    }
    if (lifecycle.compositionView.operationalPlugins.length != selectedCount ||
        startedPlugins.length != selectedCount) {
      throw StateError("composition occurred before every lifecycle settlement");
    }
    return _StartupSample(
      totalMicros: totalMicros,
      firstOperationalMicros: probe.firstOperationalMicros!,
      startMicros: probe.startMicros,
      maximumConcurrentStarts: probe.maximumConcurrentStarts,
      mutexAcquisitionCount: startupMutexRepository.acquisitionCount,
      singletonEnforcementCount: bridgeInstanceService.enforcementCount,
      stateDirectories: probe.stateDirectories,
      provisioningOrder: probe.provisioningOrder,
    );
  } finally {
    await lifecycle.dispose();
    if (runtimeDirectory.existsSync()) {
      await runtimeDirectory.delete(recursive: true);
    }
  }
}

Map<String, int> _percentiles(List<int> sorted) => {
  "p50": sorted[_percentileIndex(length: sorted.length, percentile: 0.50)],
  "p95": sorted[_percentileIndex(length: sorted.length, percentile: 0.95)],
  "p99": sorted[_percentileIndex(length: sorted.length, percentile: 0.99)],
  "max": sorted.last,
};

int _percentileIndex({required int length, required double percentile}) {
  return ((length - 1) * percentile).ceil().clamp(0, length - 1);
}

int _readInt({required List<String> args, required String name, required int fallback}) {
  final prefix = "--$name=";
  for (final argument in args) {
    if (argument.startsWith(prefix)) return int.parse(argument.substring(prefix.length));
  }
  return fallback;
}

bool _equalLists<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

int _max(int left, int right) => left > right ? left : right;

class _StartupProbe {
  _StartupProbe({required this.stopwatch});

  final Stopwatch stopwatch;
  final List<String> provisioningOrder = <String>[];
  final List<String> operations = <String>[];
  final List<String> stateDirectories = <String>[];
  final Map<String, int> startMicros = <String, int>{};
  int concurrentStarts = 0;
  int maximumConcurrentStarts = 0;
  int? firstOperationalMicros;
}

class _StartupSample {
  const _StartupSample({
    required this.totalMicros,
    required this.firstOperationalMicros,
    required this.startMicros,
    required this.maximumConcurrentStarts,
    required this.mutexAcquisitionCount,
    required this.singletonEnforcementCount,
    required this.stateDirectories,
    required this.provisioningOrder,
  });

  final int totalMicros;
  final int firstOperationalMicros;
  final Map<String, int> startMicros;
  final int maximumConcurrentStarts;
  final int mutexAcquisitionCount;
  final int singletonEnforcementCount;
  final List<String> stateDirectories;
  final List<String> provisioningOrder;
}

class _FakeDescriptor extends BridgePluginDescriptor {
  const _FakeDescriptor({required this.id, required _StartupProbe probe}) : _probe = probe;

  @override
  final String id;
  final _StartupProbe _probe;

  @override
  String get displayName => id;

  @override
  PluginStateStorage get stateStorage => PluginStateStorage.isolated;

  @override
  List<PluginOption> get options => const [];

  @override
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    _probe.provisioningOrder.add(id);
    _probe.operations.add("provision:$id");
    await Future<void>.delayed(const Duration(milliseconds: 1));
    _probe.operations.add("ready:$id");
  }

  @override
  Future<BridgePlugin> start(PluginHost host) async {
    _probe.operations.add("start:$id");
    _probe.stateDirectories.add(host.stateDirectory);
    final launchedAt = _probe.stopwatch.elapsedMicroseconds;
    _probe.concurrentStarts++;
    _probe.maximumConcurrentStarts = _max(_probe.maximumConcurrentStarts, _probe.concurrentStarts);
    await Future<void>.delayed(const Duration(milliseconds: 3));
    _probe.concurrentStarts--;
    _probe.startMicros[id] = _probe.stopwatch.elapsedMicroseconds - launchedAt;
    _probe.firstOperationalMicros ??= _probe.stopwatch.elapsedMicroseconds;
    return _FakePlugin(id: id);
  }
}

class _FakePlugin implements BridgePlugin {
  _FakePlugin({required String id}) : _api = _FakePluginApi(id);

  final _FakePluginApi _api;

  @override
  BridgePluginApi get api => _api;

  @override
  PluginStatus get currentStatus => const PluginReady();

  @override
  Stream<PluginStatus> get status => Stream<PluginStatus>.value(const PluginReady());

  @override
  PluginDiagnostics describe() => PluginDiagnostics(pluginId: _api.id, endpoint: null, details: const {});

  @override
  Future<void> shutdown({required Duration? budget}) => _api.dispose();
}

class _FakePluginApi extends NativeProjectsPluginApi {
  _FakePluginApi(this.id);

  @override
  final String id;

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStartupMutexRepository implements StartupMutexRepository {
  int acquisitionCount = 0;

  @override
  Future<T> withLock<T>({
    required int bridgePid,
    required String? bridgeStartMarker,
    required Future<T> Function() onLockAcquired,
    required Future<T> Function(StartupLockRejection rejection) onLockRejected,
  }) {
    acquisitionCount++;
    return onLockAcquired();
  }
}

class _FakeBridgeInstanceService implements BridgeInstanceService {
  int enforcementCount = 0;

  @override
  Future<BridgeInstanceResolution> enforceSingleLiveBridge({required int currentPid}) async {
    enforcementCount++;
    return const BridgeInstanceResolution(
      status: BridgeInstanceResolutionStatus.allowed,
      existingBridges: <ProcessIdentity>[],
      terminatedBridges: <ProcessIdentity>[],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProcessRepository implements ProcessRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
