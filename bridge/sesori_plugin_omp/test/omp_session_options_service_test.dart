import "package:acp_plugin/acp_plugin.dart";
import "package:omp_plugin/src/api/omp_acp_api.dart";
import "package:omp_plugin/src/models/omp_catalog_models.dart";
import "package:omp_plugin/src/repositories/omp_catalog_repository.dart";
import "package:omp_plugin/src/services/omp_catalog_service.dart";
import "package:omp_plugin/src/services/omp_session_options_service.dart";
import "package:omp_plugin/src/trackers/omp_catalog_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  late OmpCatalogTracker tracker;
  late OmpSessionOptionsService service;
  late _FakeConfigRepository configRepository;

  setUp(() {
    tracker = OmpCatalogTracker();
    final catalog = OmpProjectCatalog(
      modelConfigId: "model",
      models: const [
        OmpCatalogModel(
          value: "custom/team/model-v2",
          providerId: "custom",
          modelId: "team/model-v2",
          name: "Team Model",
        ),
        OmpCatalogModel(
          value: "other/model",
          providerId: "other",
          modelId: "model",
          name: "Other",
        ),
      ],
      defaultModelValue: "custom/team/model-v2",
      modeConfigId: "mode",
      modes: const [
        OmpCatalogOption(value: "default", name: "Default", description: null),
        OmpCatalogOption(value: "plan", name: "Plan", description: null),
      ],
      defaultModeValue: "default",
      thinkingByModel: {
        "custom/team/model-v2": OmpThinkingOptions(
          configId: "thinking",
          variants: const ["off", "high"],
          currentValue: "off",
        ),
      },
      commands: const [],
      completeness: PluginSessionOptionsCompleteness.complete,
    );
    tracker.replace(projectId: "/repo", catalog: catalog);
    service = OmpSessionOptionsService(
      catalogService: _FakeCatalogService(catalog),
      tracker: tracker,
      repository: OmpCatalogRepository(api: _UnusedAcpApi()),
      configurationTracker: AcpSessionConfigurationTracker(),
      launchDirectory: "/repo",
    );
    configRepository = _FakeConfigRepository();
  });

  test("preserves exact slash-containing model IDs and configured default", () async {
    final providers = await service.listProviders(projectId: "/repo");

    expect(providers.providers.first.id, "custom");
    expect(providers.providers.first.defaultModelID, "custom/team/model-v2");
    expect(providers.providers.first.models.single.id, "custom/team/model-v2");
    expect(providers.providers.first.models.single.variants, ["off", "high"]);
  });

  test("writes model, mode, and model-specific thinking exactly", () async {
    configRepository.results.addAll([
      _result(model: "custom/team/model-v2", mode: "default", thinking: "off"),
      _result(model: "custom/team/model-v2", mode: "plan", thinking: "off"),
      _result(model: "custom/team/model-v2", mode: "plan", thinking: "high"),
    ]);
    service.captureSessionConfig(
      _result(model: "other/model", mode: "default", thinking: "off"),
      sessionId: "session",
      fromNewSession: false,
    );

    await service.applyTurnSelection(
      configRepository: configRepository,
      sessionId: "session",
      projectId: "/repo",
      model: (providerID: "custom", modelID: "custom/team/model-v2"),
      variant: const PluginSessionVariant(id: "high"),
      agent: "Plan",
    );

    expect(configRepository.writes, [
      (configId: "model", value: "custom/team/model-v2"),
      (configId: "mode", value: "plan"),
      (configId: "thinking", value: "high"),
    ]);
  });

  test("partial application throws and cannot fail open", () async {
    configRepository.results.add(
      _result(model: "other/model", mode: "default", thinking: "off"),
    );
    service.captureSessionConfig(
      _result(model: "other/model", mode: "default", thinking: "off"),
      sessionId: "session",
      fromNewSession: false,
    );

    expect(
      service.applyTurnSelection(
        configRepository: configRepository,
        sessionId: "session",
        projectId: "/repo",
        model: (providerID: "custom", modelID: "custom/team/model-v2"),
        variant: null,
        agent: null,
      ),
      throwsA(isA<PluginOperationException>()),
    );
  });

  test("thinking mapping prefers the exact config id over another thought-level option", () {
    final result = _result(model: "other/model", mode: "default", thinking: "off");
    final configs = result.configOptions;
    configs.insert(2, {
      "id": "effort",
      "category": "thought_level",
      "currentValue": "medium",
      "options": const [
        {"value": "low", "name": "Low"},
        {"value": "medium", "name": "Medium"},
      ],
    });

    final snapshot = OmpCatalogRepository(api: _UnusedAcpApi()).mapSessionResult(result: result);

    expect(snapshot.thinking!.configId, "thinking");
    expect(snapshot.thinking!.variants, ["off", "high"]);
  });

  test("keeps no-model discovery distinct from generic failure", () async {
    final catalogService = _FakeCatalogService(
      tracker.snapshotFor(projectId: "/repo")!,
    )..result = const OmpCatalogNoModels();
    final optionsService = OmpSessionOptionsService(
      catalogService: catalogService,
      tracker: tracker,
      repository: OmpCatalogRepository(api: _UnusedAcpApi()),
      configurationTracker: AcpSessionConfigurationTracker(),
      launchDirectory: "/repo",
    );

    expect(
      await optionsService.getSessionOptions(
        projectId: "/repo",
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
      ),
      isA<OmpOptionsNoModels>(),
    );
    catalogService.result = const OmpCatalogDiscoveryFailed();
    expect(
      await optionsService.getSessionOptions(
        projectId: "/repo",
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
      ),
      isA<OmpOptionsDiscoveryFailed>(),
    );
  });
}

AcpNewSessionResult _result({required String model, required String mode, required String thinking}) =>
    AcpNewSessionResult(
      sessionId: "session",
      modes: const [],
      configOptions: [
        {
          "id": "model",
          "category": "model",
          "currentValue": model,
          "options": const [
            {"value": "custom/team/model-v2", "name": "Team Model"},
            {"value": "other/model", "name": "Other"},
          ],
        },
        {
          "id": "mode",
          "category": "mode",
          "currentValue": mode,
          "options": const [
            {"value": "default", "name": "Default"},
            {"value": "plan", "name": "Plan"},
          ],
        },
        {
          "id": "thinking",
          "category": "thought_level",
          "currentValue": thinking,
          "options": const [
            {"value": "off", "name": "Off"},
            {"value": "high", "name": "High"},
          ],
        },
      ],
      raw: const {},
    );

class _FakeConfigRepository implements AcpSessionConfigRepository {
  final List<AcpNewSessionResult> results = [];
  final List<({String configId, String value})> writes = [];

  @override
  Future<AcpNewSessionResult?> setConfigOption({
    required String sessionId,
    required String configId,
    required String value,
  }) async {
    writes.add((configId: configId, value: value));
    return results.removeAt(0);
  }
}

class _FakeCatalogService implements OmpCatalogService {
  _FakeCatalogService(this.catalog) : result = OmpCatalogObserved(catalog: catalog);

  final OmpProjectCatalog catalog;
  OmpCatalogDiscoveryResult result;

  @override
  Future<OmpCatalogDiscoveryResult> ensureCatalog({required String projectId}) async => result;

  @override
  Future<OmpCatalogDiscoveryResult> refreshCatalog({required String projectId}) async => result;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedAcpApi implements OmpAcpApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
