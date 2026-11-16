import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:deepseek_plugin/deepseek_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const selectionId = "v1c3ludGhldGlj";
  const providerId = "provider/alpha-α";
  const mapper = DeepSeekCatalogMapper();

  DeepSeekCatalogResponseDto catalog({required List<DeepSeekProviderFailureDto> failures}) =>
      DeepSeekCatalogResponseDto(
        agent: const DeepSeekAgentDto(id: "deepseek", name: "DeepSeek", primary: true),
        providers: const [
          DeepSeekProviderDto(
            id: providerId,
            name: "Synthetic Provider",
            models: [
              DeepSeekModelDto(
                id: selectionId,
                upstreamModelId: "model/alpha-α",
                name: "Synthetic Model",
                reasoningEfforts: ["high", "low"],
                defaultReasoningEffort: "low",
                supportsImages: true,
              ),
            ],
          ),
        ],
        defaultSelectionId: selectionId,
        commands: const [DeepSeekCommandDto(name: "inspect", description: "Inspect the project")],
        failures: failures,
      );

  test("a model without a declared default keeps its first-listed effort as the default", () {
    final options = mapper.map(
      const DeepSeekCatalogResponseDto(
        agent: DeepSeekAgentDto(id: "deepseek", name: "DeepSeek", primary: true),
        providers: [
          DeepSeekProviderDto(
            id: providerId,
            name: "Synthetic Provider",
            models: [
              DeepSeekModelDto(
                id: selectionId,
                upstreamModelId: "model/alpha-α",
                name: "Synthetic Model",
                reasoningEfforts: ["low", "high"],
                defaultReasoningEffort: null,
                supportsImages: true,
              ),
            ],
          ),
        ],
        defaultSelectionId: selectionId,
        commands: [],
        failures: [],
      ),
    );

    final model = options.providers.providers.single.models.single;
    expect(model.variants, ["high", "low"]);
    expect(model.defaultVariant, "low");
  });

  test("catalog mapping preserves opaque selections, variants, defaults, and commands", () {
    final options = mapper.map(
      catalog(
        failures: const [
          DeepSeekProviderFailureDto(
            providerId: "offline",
            category: "unavailable",
            message: "Provider unavailable",
          ),
        ],
      ),
    );

    expect(options.completeness, PluginSessionOptionsCompleteness.partial);
    expect(options.agents.single.name, DeepSeekIdentity.displayName);
    expect(
      options.agents.single.model,
      const PluginAgentModel(modelID: selectionId, providerID: providerId, variant: "low"),
    );
    final provider = options.providers.providers.single;
    expect([provider.id, provider.defaultModelID], [providerId, selectionId]);
    expect(provider.models.single, isA<PluginModel>().having((model) => model.id, "id", selectionId));
    expect(provider.models.single.variants, ["high", "low"]);
    expect(provider.models.single.defaultVariant, "low");
    expect(options.commands.single.name, "inspect");
    expect(mapper.map(catalog(failures: const [])).completeness, PluginSessionOptionsCompleteness.complete);
  });

  test("no listed models asks for provider setup instead of failing discovery", () async {
    final tracker = AcpSessionConfigurationTracker();
    final service = DeepSeekSessionOptionsService(
      repository: _FakeCatalogRepository(
        options: const PluginSessionOptions(
          agents: [
            PluginAgent(
              name: "deepseek",
              description: "DeepSeek session",
              model: null,
              mode: PluginAgentMode.primary,
              hidden: false,
            ),
          ],
          providers: PluginProvidersResult(providers: []),
          commands: [],
          completeness: PluginSessionOptionsCompleteness.partial,
        ),
      ),
      configurationTracker: tracker,
      pluginId: DeepSeekIdentity.id,
      discoveryTimeout: const Duration(seconds: 1),
    );
    final client = AcpStdioClient(
      launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "unused", args: []),
      processFactory: (_) async => FakeAcpProcess(),
    );

    expect(
      await service.getSessionOptions(client: client, cwd: "/project"),
      isA<PluginSessionOptionsDiscoveryAuthenticationRequired>().having(
        (r) => r.actionHint,
        "actionHint",
        contains("API key"),
      ),
    );
    expect(tracker.processDefaults.modelId, isNull);
  });

  test("selection writes model then reasoning and updates identity only after success", () async {
    final tracker = AcpSessionConfigurationTracker();
    final service = DeepSeekSessionOptionsService(
      repository: _FakeCatalogRepository(options: mapper.map(catalog(failures: const []))),
      configurationTracker: tracker,
      pluginId: DeepSeekIdentity.id,
      discoveryTimeout: const Duration(seconds: 1),
    );
    final repository = _FakeConfigRepository();

    await service.applyTurnSelection(
      configRepository: repository,
      sessionId: "session-1",
      model: (providerID: providerId, modelID: selectionId),
      variant: const PluginSessionVariant(id: "high"),
    );

    expect(repository.writes, [
      (configId: DeepSeekSessionOptionsService.modelConfigId, value: selectionId),
      (configId: DeepSeekSessionOptionsService.reasoningConfigId, value: "high"),
    ]);
    expect(tracker.snapshotForSession(sessionId: "session-1").modelId, selectionId);

    final failing = _FakeConfigRepository(failAt: 2);
    await expectLater(
      service.applyTurnSelection(
        configRepository: failing,
        sessionId: "session-2",
        model: (providerID: providerId, modelID: selectionId),
        variant: const PluginSessionVariant(id: "low"),
      ),
      throwsA(
        isA<PluginOperationException>().having((error) => error.cause, "cause", isA<StateError>()),
      ),
    );
    expect(failing.writes.map((write) => write.configId), [
      DeepSeekSessionOptionsService.modelConfigId,
      DeepSeekSessionOptionsService.reasoningConfigId,
    ]);
    expect(tracker.snapshotForSession(sessionId: "session-2").modelId, isNull);
  });

  test("refuses a model or reasoning level the last catalog no longer lists", () async {
    final tracker = AcpSessionConfigurationTracker();
    final service = DeepSeekSessionOptionsService(
      repository: _FakeCatalogRepository(options: mapper.map(catalog(failures: const []))),
      configurationTracker: tracker,
      pluginId: DeepSeekIdentity.id,
      discoveryTimeout: const Duration(seconds: 1),
    );
    final client = AcpStdioClient(
      launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "unused", args: []),
      processFactory: (_) async => FakeAcpProcess(),
    );
    void validate({required String modelId, required String? variant}) => service.validateTurnSelection(
      operation: "sendPrompt",
      sessionId: "session-1",
      cwd: "/project",
      model: (providerID: providerId, modelID: modelId),
      variant: variant == null ? null : PluginSessionVariant(id: variant),
    );

    validate(modelId: "retired", variant: null);
    await service.getSessionOptions(client: client, cwd: "/project");

    expect(() => validate(modelId: "retired", variant: null), throwsA(isA<PluginStaleOptionsException>()));
    expect(() => validate(modelId: selectionId, variant: "max"), throwsA(isA<PluginStaleOptionsException>()));
    validate(modelId: selectionId, variant: "high");
  });

  test("session config capture derives provider without decoding the opaque model id", () {
    final tracker = AcpSessionConfigurationTracker();
    final service = DeepSeekSessionOptionsService(
      repository: _FakeCatalogRepository(options: mapper.map(catalog(failures: const []))),
      configurationTracker: tracker,
      pluginId: DeepSeekIdentity.id,
      discoveryTimeout: const Duration(seconds: 1),
    );
    service.captureSessionConfig(
      const AcpNewSessionResult(
        sessionId: "session-1",
        modes: [],
        configOptions: [
          {
            "id": "deepseek.model",
            "currentValue": selectionId,
            "options": [
              {
                "group": providerId,
                "options": [
                  {"value": selectionId, "name": "Synthetic Model"},
                ],
              },
            ],
          },
          {"id": "deepseek.reasoning_effort", "currentValue": "high"},
        ],
        raw: {},
      ),
      sessionId: "session-1",
      fromNewSession: true,
    );

    expect(tracker.processDefaults.modelId, selectionId);
    expect(tracker.snapshotForSession(sessionId: "session-1").providerId, providerId);

    // No catalog for a dedicated worktree's directory: the session's own
    // offered models still catch a stale model.
    void validateIn(String modelId) => service.validateTurnSelection(
      operation: "sendPrompt",
      sessionId: "session-1",
      cwd: "/worktrees/session-1",
      model: (providerID: providerId, modelID: modelId),
      variant: null,
    );
    expect(() => validateIn("retired"), throwsA(isA<PluginStaleOptionsException>()));
    validateIn(selectionId);
  });

  test("a model that lists no reasoning levels refuses any, and an empty catalog stops the check", () async {
    final repository = _FakeCatalogRepository(
      options: mapper.map(
        const DeepSeekCatalogResponseDto(
          agent: DeepSeekAgentDto(id: "deepseek", name: "DeepSeek", primary: true),
          providers: [
            DeepSeekProviderDto(
              id: providerId,
              name: "Synthetic Provider",
              models: [
                DeepSeekModelDto(
                  id: selectionId,
                  upstreamModelId: "model/alpha-α",
                  name: "Synthetic Model",
                  reasoningEfforts: [],
                  defaultReasoningEffort: null,
                  supportsImages: true,
                ),
              ],
            ),
          ],
          defaultSelectionId: selectionId,
          commands: [],
          failures: [],
        ),
      ),
    );
    final service = DeepSeekSessionOptionsService(
      repository: repository,
      configurationTracker: AcpSessionConfigurationTracker(),
      pluginId: DeepSeekIdentity.id,
      discoveryTimeout: const Duration(seconds: 1),
    );
    final client = AcpStdioClient(
      launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "unused", args: []),
      processFactory: (_) async => FakeAcpProcess(),
    );
    void validate() => service.validateTurnSelection(
      operation: "sendPrompt",
      sessionId: "session-1",
      cwd: "/project",
      model: (providerID: providerId, modelID: "retired"),
      variant: const PluginSessionVariant(id: "high"),
    );

    await service.getSessionOptions(client: client, cwd: "/project");
    expect(
      () => service.validateTurnSelection(
        operation: "sendPrompt",
        sessionId: "session-1",
        cwd: "/project",
        model: (providerID: providerId, modelID: selectionId),
        variant: const PluginSessionVariant(id: "high"),
      ),
      throwsA(isA<PluginStaleOptionsException>()),
    );
    expect(validate, throwsA(isA<PluginStaleOptionsException>()));

    repository.laterOptions = const PluginSessionOptions(
      agents: [
        PluginAgent(
          name: "deepseek",
          description: "DeepSeek session",
          model: null,
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
      ],
      providers: PluginProvidersResult(providers: []),
      commands: [],
      completeness: PluginSessionOptionsCompleteness.partial,
    );
    await service.getSessionOptions(client: client, cwd: "/project");
    validate();
  });
}

class _FakeCatalogRepository({required final PluginSessionOptions options}) extends DeepSeekCatalogRepository {
  this
    : super(
        api: const DeepSeekAcpApi(pluginId: DeepSeekIdentity.id),
        mapper: const DeepSeekCatalogMapper(),
      );

  /// What a later discovery reports instead of [options].
  PluginSessionOptions? laterOptions;

  @override
  Future<PluginSessionOptions> discover({
    required AcpStdioClient client,
    required String cwd,
    required Duration timeout,
  }) async => laterOptions ?? options;
}

class _FakeConfigRepository({final int? failAt}) implements AcpSessionConfigRepository {
  final List<({String configId, String value})> writes = [];

  @override
  Future<void> setMode({required String sessionId, required String modeId}) =>
      throw UnsupportedError("DeepSeek options must not write ACP session modes");

  @override
  Future<AcpNewSessionResult?> setConfigOption({
    required String sessionId,
    required String configId,
    required String value,
  }) async {
    writes.add((configId: configId, value: value));
    if (writes.length == failAt) throw StateError("rejected");
    return null;
  }
}
