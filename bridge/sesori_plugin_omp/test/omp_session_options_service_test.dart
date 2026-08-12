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

    await service.applyTurnSelection(
      configRepository: configRepository,
      sessionId: "session",
      projectId: "/repo",
      liveSnapshot: _snapshot(model: "other/model", mode: "default", thinking: "off"),
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

    expect(
      service.applyTurnSelection(
        configRepository: configRepository,
        sessionId: "session",
        projectId: "/repo",
        liveSnapshot: _snapshot(model: "other/model", mode: "default", thinking: "off"),
        model: (providerID: "custom", modelID: "custom/team/model-v2"),
        variant: null,
        agent: null,
      ),
      throwsA(isA<PluginOperationException>()),
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

OmpSessionConfigSnapshot _snapshot({required String model, required String mode, required String thinking}) =>
    OmpCatalogRepository(api: _UnusedAcpApi()).mapSessionResult(
      result: _result(model: model, mode: mode, thinking: thinking),
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
  _FakeCatalogService(this.catalog);

  final OmpProjectCatalog catalog;

  @override
  Future<OmpProjectCatalog?> ensureCatalog({required String projectId}) async => catalog;

  @override
  Future<OmpProjectCatalog?> refreshCatalog({required String projectId}) async => catalog;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedAcpApi implements OmpAcpApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
