import "dart:async";

import "package:path/path.dart" as path;
import "package:pi_plugin/pi_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("normalizes per-project reuse and refresh replaces tracked snapshots", () async {
    final first = _options(command: "first", completeness: PluginSessionOptionsCompleteness.complete);
    final refreshed = _options(command: "refreshed", completeness: PluginSessionOptionsCompleteness.partial);
    final repository = _FakeCatalogRepository(results: [first, refreshed]);
    final tracker = PiCatalogTracker();
    final service = _service(repository: repository, tracker: tracker);
    final project = path.absolute("project");

    final observed = await service.getSessionOptions(
      projectId: "$project${path.separator}.${path.separator}",
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
    );
    final reused = await service.getSessionOptions(
      projectId: project,
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
    );
    final refresh = await service.getSessionOptions(
      projectId: project,
      discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
    );

    final observedOptions = (observed as PluginSessionOptionsDiscoveryObserved).options;
    final refreshOptions = (refresh as PluginSessionOptionsDiscoveryObserved).options;
    expect(observedOptions.commands.single.name, "first");
    expect((reused as PluginSessionOptionsDiscoveryObserved).options, same(observedOptions));
    expect(refreshOptions.commands.single.name, "refreshed");
    expect(refreshOptions.completeness, PluginSessionOptionsCompleteness.partial);
    expect(repository.projects, [path.normalize(project), path.normalize(project)]);
    expect(tracker.snapshotFor(projectId: project), same(refreshOptions));
  });

  test("coalesces same-project probes while different projects probe concurrently", () async {
    final first = Completer<PluginSessionOptions>();
    final second = Completer<PluginSessionOptions>();
    final repository = _FakeCatalogRepository(results: [first.future, second.future]);
    final service = _service(repository: repository, tracker: PiCatalogTracker());

    final alphaOne = service.getSessionOptions(
      projectId: path.absolute("alpha"),
      discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
    );
    final alphaTwo = service.getSessionOptions(
      projectId: path.absolute("alpha${path.separator}."),
      discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
    );
    final beta = service.getSessionOptions(
      projectId: path.absolute("beta"),
      discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
    );
    await Future<void>.delayed(Duration.zero);

    expect(repository.active, 2);
    expect(repository.maxActive, 2);
    expect(repository.projects, [path.normalize(path.absolute("alpha")), path.normalize(path.absolute("beta"))]);
    first.complete(_options(command: "alpha", completeness: PluginSessionOptionsCompleteness.complete));
    await alphaOne;
    await alphaTwo;
    second.complete(_options(command: "beta", completeness: PluginSessionOptionsCompleteness.complete));
    await beta;
    expect(repository.maxActive, 2);
  });

  test("total failure returns failed and preserves last good snapshot", () async {
    final good = _options(command: "good", completeness: PluginSessionOptionsCompleteness.complete);
    final repository = _FakeCatalogRepository(results: [good, StateError("no models")]);
    final tracker = PiCatalogTracker();
    final service = _service(repository: repository, tracker: tracker);
    final project = path.absolute("project");

    final firstObserved = await service.getSessionOptions(
      projectId: project,
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
    );
    final trackedGood = (firstObserved as PluginSessionOptionsDiscoveryObserved).options;
    final failed = await service.getSessionOptions(
      projectId: project,
      discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
    );
    final fallback = await service.getSessionOptions(
      projectId: project,
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
    );

    expect(failed, isA<PluginSessionOptionsDiscoveryFailed>());
    expect((fallback as PluginSessionOptionsDiscoveryObserved).options, same(trackedGood));
    expect(tracker.snapshotFor(projectId: project), same(trackedGood));
    expect(repository.projects, hasLength(2));
  });
}

PiCatalogService _service({required PiBackendCatalogRepository repository, required PiCatalogTracker tracker}) =>
    PiCatalogService(
      repository: repository,
      tracker: tracker,
      totalTimeout: const Duration(seconds: 2),
      maxModels: 4,
    );

PluginSessionOptions _options({
  required String command,
  required PluginSessionOptionsCompleteness completeness,
}) => PluginSessionOptions(
  agents: const [],
  providers: const PluginProvidersResult(providers: []),
  commands: [PluginCommand(name: command, provider: null)],
  completeness: completeness,
);

class _FakeCatalogRepository({required final List<Object> results}) implements PiBackendCatalogRepository {
  final List<String> projects = [];
  int active = 0;
  int maxActive = 0;

  @override
  Future<bool> healthCheck() async => true;

  @override
  Future<PiCatalogProbeSnapshot> probe({
    required String projectId,
    required Duration totalTimeout,
    required int maxModels,
  }) async {
    projects.add(projectId);
    active++;
    if (active > maxActive) maxActive = active;
    final result = results.removeAt(0);
    try {
      final options = switch (result) {
        Future<PluginSessionOptions>() => await result,
        PluginSessionOptions() => result,
        _ => throw result,
      };
      return (
        agents: options.agents,
        providers: options.providers,
        commands: options.commands,
        complete: options.completeness == PluginSessionOptionsCompleteness.complete,
      );
    } finally {
      active--;
    }
  }
}
