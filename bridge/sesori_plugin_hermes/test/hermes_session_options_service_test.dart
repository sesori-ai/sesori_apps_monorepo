import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:hermes_plugin/src/models/hermes_model_catalog.dart";
import "package:hermes_plugin/src/repositories/hermes_catalog_repository.dart";
import "package:hermes_plugin/src/services/hermes_session_options_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("coalesces first discovery and reuses the process-scoped catalog", () async {
    final discovery = Completer<HermesModelCatalog>();
    final repository = _FakeCatalogRepository()..discoveries.add(discovery.future);
    final service = _service(repository: repository);
    addTearDown(service.dispose);

    final first = service.getSessionOptions(
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
    );
    final concurrent = service.getSessionOptions(
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
    );
    expect(repository.discoveryCount, 1);

    discovery.complete(_catalog());
    final firstOptions = (await first as PluginSessionOptionsDiscoveryObserved).options;
    final concurrentOptions = (await concurrent as PluginSessionOptionsDiscoveryObserved).options;
    final provider = firstOptions.providers.providers.single;
    expect(provider.id, "opencode-go");
    expect(provider.name, "OpenCode Go");
    expect(provider.defaultModelID, "opencode-go:deepseek-v4-flash");
    expect(provider.models.map((model) => model.id), [
      "opencode-go:deepseek-v4-flash",
      "opencode-go:gpt-5",
    ]);
    expect(concurrentOptions, firstOptions);

    await service.getSessionOptions(
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
    );
    expect(repository.discoveryCount, 1);
  });

  test("cleanup failure preserves the configured-model fallback", () async {
    final repository = _FakeCatalogRepository()..discoveries.add(Future.error(StateError("delete failed")));
    final service = _service(repository: repository);
    addTearDown(service.dispose);

    final result = await service.getSessionOptions(
      discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
    );
    final options = (result as PluginSessionOptionsDiscoveryObserved).options;

    expect(options.providers.providers.single.id, "OpenCode Go");
    expect(options.providers.providers.single.models.single.id, "DeepSeek-V4-Flash");
  });

  test("failed explicit refresh retains but does not report the cached catalog", () async {
    final repository = _FakeCatalogRepository()
      ..discoveries.add(Future.value(_catalog()))
      ..discoveries.add(Future.error(StateError("refresh failed")));
    final service = _service(repository: repository);
    addTearDown(service.dispose);

    expect(
      await service.getSessionOptions(
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      ),
      isA<PluginSessionOptionsDiscoveryObserved>(),
    );
    expect(
      await service.getSessionOptions(
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
      ),
      isA<PluginSessionOptionsDiscoveryFailed>(),
    );
    expect(
      await service.getSessionOptions(
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      ),
      isA<PluginSessionOptionsDiscoveryObserved>(),
    );
    expect(repository.discoveryCount, 2);
  });
}

HermesSessionOptionsService _service({required _FakeCatalogRepository repository}) {
  final configurationTracker = AcpSessionConfigurationTracker()
    ..setProcessDefaults(
      modelId: "DeepSeek-V4-Flash",
      providerId: "OpenCode Go",
    );
  return HermesSessionOptionsService(
    repository: repository,
    configurationTracker: configurationTracker,
    commandTracker: AcpCommandTracker(),
    launchDirectory: "/repo",
    pluginId: "hermes",
    agentDisplayName: "Hermes Agent",
    discoveryTimeout: const Duration(seconds: 2),
  );
}

HermesModelCatalog _catalog() => HermesModelCatalog(
  models: const [
    HermesCatalogModel(
      value: "opencode-go:deepseek-v4-flash",
      providerId: "opencode-go",
      providerName: "OpenCode Go",
      modelId: "deepseek-v4-flash",
      name: "deepseek-v4-flash",
    ),
    HermesCatalogModel(
      value: "opencode-go:gpt-5",
      providerId: "opencode-go",
      providerName: "OpenCode Go",
      modelId: "gpt-5",
      name: "GPT-5",
    ),
  ],
  currentModelValue: "opencode-go:deepseek-v4-flash",
);

class _FakeCatalogRepository() implements HermesCatalogRepository {
  final List<Future<HermesModelCatalog>> discoveries = [];
  int discoveryCount = 0;

  @override
  Future<HermesModelCatalog> discoverCatalog({
    required String cwd,
    required Duration timeout,
  }) {
    final result = discoveries[discoveryCount];
    discoveryCount++;
    return result;
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
