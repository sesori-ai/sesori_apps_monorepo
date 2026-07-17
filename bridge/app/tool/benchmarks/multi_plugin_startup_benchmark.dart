import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

Future<void> main(List<String> args) async {
  final selectedCount = _readInt(args: args, name: "plugins", fallback: 1);
  final warmupCount = _readInt(args: args, name: "warmup", fallback: 3);
  final sampleCount = _readInt(args: args, name: "samples", fallback: 20);
  if (![1, 3, 8].contains(selectedCount)) {
    throw ArgumentError.value(selectedCount, "plugins", "must be 1, 3, or 8");
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
  final descriptors = [for (var index = 0; index < selectedCount; index++) _FakeDescriptor("plugin-$index")];
  final lifecycle = PluginLifecycleService()
    ..registerSelection(
      knownPluginIds: {for (final descriptor in descriptors) descriptor.id},
      enabledPlugins: [
        for (var index = 0; index < descriptors.length; index++)
          (id: descriptors[index].id, displayName: descriptors[index].displayName, isDefault: index == 0),
      ],
    );
  final stopwatch = Stopwatch()..start();
  final provisioningOrder = <String>[];
  final launchAt = <String, int>{};
  final startMicros = <String, int>{};
  final stateDirectories = <String>[];
  final settlements = <Future<void>>[];
  var mutexAcquisitionCount = 0;
  var singletonEnforcementCount = 0;
  var concurrentStarts = 0;
  var maximumConcurrentStarts = 0;
  int? firstOperationalMicros;

  mutexAcquisitionCount++;
  singletonEnforcementCount++;
  for (final descriptor in descriptors) {
    final stateDirectory = "/fixture/plugins/${descriptor.id}";
    stateDirectories.add(stateDirectory);
    provisioningOrder.add(descriptor.id);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    launchAt[descriptor.id] = stopwatch.elapsedMicroseconds;
    concurrentStarts++;
    maximumConcurrentStarts = _max(maximumConcurrentStarts, concurrentStarts);
    final startFuture = Future<BridgePlugin>.delayed(const Duration(milliseconds: 3), () {
      concurrentStarts--;
      startMicros[descriptor.id] = stopwatch.elapsedMicroseconds - launchAt[descriptor.id]!;
      firstOperationalMicros ??= stopwatch.elapsedMicroseconds;
      return _FakePlugin(id: descriptor.id);
    });
    settlements.add(
      lifecycle.registerStart(
        id: descriptor.id,
        startFuture: startFuture,
        shutdownBudget: const Duration(seconds: 1),
      ),
    );
  }
  await Future.wait(settlements);
  final totalMicros = stopwatch.elapsedMicroseconds;

  if (mutexAcquisitionCount != 1 || singletonEnforcementCount != 1) {
    throw StateError("startup fixture did not use one mutex/enforcement");
  }
  if (stateDirectories.toSet().length != selectedCount) {
    throw StateError("plugin state directories are not unique");
  }
  if (provisioningOrder.join(",") != descriptors.map((descriptor) => descriptor.id).join(",")) {
    throw StateError("provisioning order changed");
  }
  if (selectedCount > 1 && maximumConcurrentStarts < 2) {
    throw StateError("plugin starts did not overlap");
  }
  if (lifecycle.compositionView.operationalPlugins.length != selectedCount) {
    throw StateError("composition occurred before every lifecycle settlement");
  }
  await lifecycle.dispose();
  return _StartupSample(
    totalMicros: totalMicros,
    firstOperationalMicros: firstOperationalMicros!,
    startMicros: startMicros,
    maximumConcurrentStarts: maximumConcurrentStarts,
    mutexAcquisitionCount: mutexAcquisitionCount,
    singletonEnforcementCount: singletonEnforcementCount,
    stateDirectories: stateDirectories,
    provisioningOrder: provisioningOrder,
  );
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

int _max(int left, int right) => left > right ? left : right;

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
  const _FakeDescriptor(this.id);

  @override
  final String id;

  @override
  String get displayName => id;

  @override
  List<PluginOption> get options => const [];

  @override
  Future<BridgePlugin> start(PluginHost host) async => _FakePlugin(id: id);
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
