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

    final observedOptions = (observed as PiOptionsObserved).options;
    final refreshOptions = (refresh as PiOptionsObserved).options;
    expect(observedOptions.commands.single.name, "first");
    expect((reused as PiOptionsObserved).options, same(observedOptions));
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
    final trackedGood = (firstObserved as PiOptionsObserved).options;
    final failed = await service.getSessionOptions(
      projectId: project,
      discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
    );
    final fallback = await service.getSessionOptions(
      projectId: project,
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
    );

    expect(failed, isA<PiOptionsDiscoveryFailed>());
    expect((fallback as PiOptionsObserved).options, same(trackedGood));
    expect(tracker.snapshotFor(projectId: project), same(trackedGood));
    expect(repository.projects, hasLength(2));
  });

  test("no-model discovery stays distinct and preserves the last good snapshot", () async {
    final good = _options(command: "good", completeness: PluginSessionOptionsCompleteness.complete);
    final repository = _FakeCatalogRepository(results: [good, const PiCatalogProbeNoModels()]);
    final tracker = PiCatalogTracker();
    final service = _service(repository: repository, tracker: tracker);
    final project = path.absolute("project");

    final observed = await service.getSessionOptions(
      projectId: project,
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
    );
    final trackedGood = (observed as PiOptionsObserved).options;
    final noModels = await service.getSessionOptions(
      projectId: project,
      discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
    );
    final fallback = await service.getSessionOptions(
      projectId: project,
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
    );

    expect(noModels, isA<PiOptionsNoModels>());
    expect((fallback as PiOptionsObserved).options, same(trackedGood));
    expect(tracker.snapshotFor(projectId: project), same(trackedGood));
  });

  test("required options identify missing models with a typed cause", () async {
    final service = _service(
      repository: _FakeCatalogRepository(results: [const PiCatalogProbeNoModels()]),
      tracker: PiCatalogTracker(),
    );

    await expectLater(
      service.requireOptions(projectId: path.absolute("project")),
      throwsA(
        isA<PluginOperationException>().having(
          (error) => error.cause,
          "cause",
          isA<PiCatalogNoModelsException>(),
        ),
      ),
    );
  });

  test("required options preserve the catalog probe failure as cause", () async {
    final failure = StateError("private probe failure");
    final service = _service(
      repository: _FakeCatalogRepository(results: [failure]),
      tracker: PiCatalogTracker(),
    );

    await expectLater(
      service.requireOptions(projectId: path.absolute("project")),
      throwsA(
        isA<PluginOperationException>().having((error) => error.cause, "cause", same(failure)),
      ),
    );
  });
}

PiCatalogService _service({required PiBackendCatalogRepository repository, required PiCatalogTracker tracker}) =>
    PiCatalogService(
      repository: repository,
      tracker: tracker,
      totalTimeout: const Duration(seconds: 2),
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
  Future<PiCatalogProbeResult> probe({
    required String projectId,
    required Duration totalTimeout,
  }) async {
    projects.add(projectId);
    active++;
    if (active > maxActive) maxActive = active;
    final result = results.removeAt(0);
    try {
      if (result is PiCatalogProbeResult) return result;
      final options = switch (result) {
        Future<PluginSessionOptions>() => await result,
        PluginSessionOptions() => result,
        _ => throw result,
      };
      return PiCatalogProbeObserved(
        snapshot: (
          agents: options.agents,
          providers: options.providers,
          commands: options.commands,
          complete: options.completeness == PluginSessionOptionsCompleteness.complete,
        ),
      );
    } finally {
      active--;
    }
  }
}
