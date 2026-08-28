import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:grok_plugin/src/api/grok_acp_api.dart";
import "package:grok_plugin/src/grok_identity.dart";
import "package:grok_plugin/src/repositories/grok_catalog_repository.dart";
import "package:grok_plugin/src/repositories/grok_session_config_repository.dart";
import "package:grok_plugin/src/services/grok_session_options_service.dart";
import "package:grok_plugin/src/trackers/grok_catalog_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("discovers and reuses one Grok provider with exact reasoning values", () async {
    final api = _FakeGrokAcpApi()..probes.add(() async => _initializeResult());
    final fixture = _service(api: api);

    final first = await fixture.service.getSessionOptions(
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
    );
    final options = (first as PluginSessionOptionsDiscoveryObserved).options;
    final provider = options.providers.providers.single;
    expect(api.probeCount, 1);
    expect(provider.id, GrokPluginIdentity.id);
    expect(provider.defaultModelID, "synthetic:model-alpha");
    expect(provider.models.first.variants, ["high", "low"]);
    expect(options.agents.single.model?.variant, "high");
    expect(options.completeness, PluginSessionOptionsCompleteness.complete);

    await fixture.service.getSessionOptions(discoveryMode: PluginSessionOptionsDiscoveryMode.reuse);
    expect(api.probeCount, 1);
  });

  test("failed refresh retains the last-good catalog without reporting success", () async {
    final api = _FakeGrokAcpApi()
      ..probes.add(() async => _initializeResult())
      ..probes.add(() => Future.error(StateError("refresh failed")));
    final fixture = _service(api: api);

    await fixture.service.getSessionOptions(discoveryMode: PluginSessionOptionsDiscoveryMode.reuse);
    expect(
      await fixture.service.getSessionOptions(discoveryMode: PluginSessionOptionsDiscoveryMode.refresh),
      isA<PluginSessionOptionsDiscoveryFailed>(),
    );
    final reused = await fixture.service.getSessionOptions(
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
    );
    expect((reused as PluginSessionOptionsDiscoveryObserved).options.providers.providers, hasLength(1));
    expect(api.probeCount, 2);
  });

  test("initialize, new, and load captures replace catalog without load changing process defaults", () async {
    final fixture = _service(api: _FakeGrokAcpApi());
    fixture.service.captureInitializeResult(result: _initializeResult());
    expect(fixture.catalogTracker.snapshot?.currentModel?.id, "synthetic:model-alpha");
    expect((await fixture.service.listAgents()).single.model?.variant, "high");

    final loaded = _jsonFixture(name: "initialize.json");
    final loadedMeta = loaded["_meta"] as Map<String, dynamic>;
    final loadedModelState = loadedMeta["modelState"] as Map<String, dynamic>;
    loadedModelState["currentModelId"] = "opaque/provider:model-beta";
    final loadedModels = loadedModelState["availableModels"] as List<dynamic>;
    final loadedDefaultModel = loadedModels.first as Map<String, dynamic>;
    final loadedDefaultMeta = loadedDefaultModel["_meta"] as Map<String, dynamic>;
    loadedDefaultMeta["reasoningEffort"] = "low";
    fixture.service.captureSessionConfig(
      result: AcpNewSessionResult.fromJson({"sessionId": "loaded-session", "models": loadedModelState}),
      sessionId: "loaded-session",
      fromNewSession: false,
    );
    expect(fixture.catalogTracker.snapshot?.currentModel?.id, "opaque/provider:model-beta");
    expect(fixture.configurationTracker.processDefaults.modelId, "synthetic:model-alpha");
    expect(
      fixture.configurationTracker.snapshotForSession(sessionId: "loaded-session").modelId,
      "opaque/provider:model-beta",
    );
    expect((await fixture.service.listAgents()).single.model?.variant, "high");
    expect(fixture.service.reasoningEffortForSession(sessionId: "loaded-session"), isNull);

    loadedModelState["currentModelId"] = "synthetic:model-alpha";
    fixture.service.captureSessionConfig(
      result: AcpNewSessionResult.fromJson({"sessionId": "reasoning-session", "models": loadedModelState}),
      sessionId: "reasoning-session",
      fromNewSession: false,
    );
    expect(fixture.service.reasoningEffortForSession(sessionId: "reasoning-session"), "low");
    expect((await fixture.service.listAgents()).single.model?.variant, "high");
    fixture.service.captureSessionConfig(
      result: AcpNewSessionResult.fromJson(_jsonFixture(name: "session.json")),
      sessionId: "new-session",
      fromNewSession: true,
    );
    expect(fixture.configurationTracker.processDefaults.modelId, "opaque/provider:model-beta");
  });

  test("applies model-only and effort selections through the config repository", () async {
    final api = _FakeGrokAcpApi();
    final fixture = _service(api: api);
    fixture.service.captureInitializeResult(result: _initializeResult());

    await fixture.service.applyTurnSelection(
      liveClient: _FakeAcpStdioClient(),
      sessionId: "s1",
      model: null,
      variant: const PluginSessionVariant(id: "low"),
    );
    await fixture.service.applyTurnSelection(
      liveClient: _FakeAcpStdioClient(),
      sessionId: "s1",
      model: const (providerID: GrokPluginIdentity.id, modelID: "opaque/provider:model-beta"),
      variant: null,
    );

    expect(api.selections, [
      (sessionId: "s1", modelId: "synthetic:model-alpha", reasoningEffort: "low"),
      (sessionId: "s1", modelId: "opaque/provider:model-beta", reasoningEffort: null),
    ]);
  });

  test("effort-only selection uses the advertised model fallback", () async {
    final api = _FakeGrokAcpApi();
    final fixture = _service(api: api);
    final initialize = _jsonFixture(name: "initialize.json");
    final meta = initialize["_meta"] as Map<String, dynamic>;
    final modelState = meta["modelState"] as Map<String, dynamic>;
    modelState.remove("currentModelId");
    fixture.service.captureInitializeResult(result: AcpInitializeResult.fromJson(initialize));

    final options = await fixture.service.listProviders();
    expect(options.providers.single.defaultModelID, "synthetic:model-alpha");
    await fixture.service.applyTurnSelection(
      liveClient: _FakeAcpStdioClient(),
      sessionId: "s1",
      model: null,
      variant: const PluginSessionVariant(id: "low"),
    );

    expect(api.selections.single, (sessionId: "s1", modelId: "synthetic:model-alpha", reasoningEffort: "low"));
  });

  test("rejects stale selections before the API call", () async {
    final api = _FakeGrokAcpApi();
    final fixture = _service(api: api);
    fixture.service.captureInitializeResult(result: _initializeResult());

    await expectLater(
      fixture.service.applyTurnSelection(
        liveClient: _FakeAcpStdioClient(),
        sessionId: "s1",
        model: const (providerID: "removed-provider", modelID: "synthetic:model-alpha"),
        variant: null,
      ),
      throwsA(isA<PluginStaleOptionsException>()),
    );
    await expectLater(
      fixture.service.applyTurnSelection(
        liveClient: _FakeAcpStdioClient(),
        sessionId: "s1",
        model: const (providerID: GrokPluginIdentity.id, modelID: "missing"),
        variant: null,
      ),
      throwsA(isA<PluginStaleOptionsException>()),
    );
    await expectLater(
      fixture.service.applyTurnSelection(
        liveClient: _FakeAcpStdioClient(),
        sessionId: "s1",
        model: null,
        variant: const PluginSessionVariant(id: "unknown"),
      ),
      throwsA(isA<PluginStaleOptionsException>()),
    );
    expect(api.selections, isEmpty);
  });

  test("failed selection preserves the original cause and tracker state", () async {
    final api = _FakeGrokAcpApi()..selectionError = StateError("rejected");
    final fixture = _service(api: api);
    fixture.service.captureInitializeResult(result: _initializeResult());

    Object? failure;
    try {
      await fixture.service.applyTurnSelection(
        liveClient: _FakeAcpStdioClient(),
        sessionId: "s1",
        model: const (providerID: GrokPluginIdentity.id, modelID: "opaque/provider:model-beta"),
        variant: null,
      );
    } on Object catch (error) {
      failure = error;
    }
    expect(failure, isA<PluginOperationException>());
    expect((failure! as PluginOperationException).cause, isA<StateError>());
    expect(fixture.configurationTracker.snapshotForSession(sessionId: "s1").modelId, "synthetic:model-alpha");
  });
}

({
  GrokSessionOptionsService service,
  GrokCatalogTracker catalogTracker,
  AcpSessionConfigurationTracker configurationTracker,
})
_service({required _FakeGrokAcpApi api}) {
  final catalogTracker = GrokCatalogTracker();
  final configurationTracker = AcpSessionConfigurationTracker();
  final commandTracker = AcpCommandTracker()..replaceSnapshot(commands: const []);
  final catalogRepository = GrokCatalogRepository(api: api);
  return (
    service: GrokSessionOptionsService(
      catalogRepository: catalogRepository,
      configRepository: GrokSessionConfigRepository(api: api),
      catalogTracker: catalogTracker,
      configurationTracker: configurationTracker,
      commandTracker: commandTracker,
      launchDirectory: "/repo",
      pluginId: GrokPluginIdentity.id,
      displayName: GrokPluginIdentity.displayName,
      discoveryTimeout: const Duration(seconds: 2),
    ),
    catalogTracker: catalogTracker,
    configurationTracker: configurationTracker,
  );
}

AcpInitializeResult _initializeResult() => AcpInitializeResult.fromJson(
  _jsonFixture(name: "initialize.json"),
);

Map<String, dynamic> _jsonFixture({required String name}) {
  final decoded = jsonDecode(File("test/fixtures/protocol/v1/$name").readAsStringSync());
  return (decoded! as Map<dynamic, dynamic>).cast<String, dynamic>();
}

class _FakeGrokAcpApi() implements GrokAcpApi {
  final List<Future<AcpInitializeResult> Function()> probes = [];
  final List<({String sessionId, String modelId, String? reasoningEffort})> selections = [];
  int probeCount = 0;
  Object? selectionError;

  @override
  Future<AcpInitializeResult> probeCatalog({required String cwd, required Duration timeout}) {
    final probe = probes[probeCount];
    probeCount++;
    return probe();
  }

  @override
  Future<void> setModel({
    required AcpStdioClient liveClient,
    required String sessionId,
    required String modelId,
    required String? reasoningEffort,
    required Duration timeout,
  }) async {
    final error = selectionError;
    if (error != null) throw error;
    selections.add((sessionId: sessionId, modelId: modelId, reasoningEffort: reasoningEffort));
  }
}

class _FakeAcpStdioClient() implements AcpStdioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
