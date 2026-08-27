import "package:acp_plugin/acp_plugin.dart";
import "package:copilot_plugin/src/repositories/copilot_catalog_repository.dart";
import "package:copilot_plugin/src/services/copilot_session_options_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("CopilotSessionOptionsService", () {
    late AcpCommandTracker commands;
    late AcpSessionConfigurationTracker configurations;
    late _CatalogRepository repository;
    late CopilotSessionOptionsService service;

    setUp(() {
      commands = AcpCommandTracker()
        ..replaceSnapshot(
          commands: const [
            PluginCommand(
              name: "review",
              description: "Review changes",
              hints: [],
              provider: null,
              source: PluginCommandSource.command,
            ),
          ],
        );
      configurations = AcpSessionConfigurationTracker();
      repository = _CatalogRepository(result: _sessionResult());
      service = CopilotSessionOptionsService(
        commandTracker: commands,
        configurationTracker: configurations,
        repository: repository,
        launchDirectory: "/project",
        discoveryTimeout: const Duration(seconds: 1),
      );
    });

    tearDown(() => service.dispose());

    test("discovers standard model, mode, reasoning, and command options", () async {
      final result = await service.getSessionOptions(
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      );

      final options = (result as PluginSessionOptionsDiscoveryObserved).options;
      expect(repository.createdDirectories, ["/project"]);
      expect(repository.closedSessions, ["catalog-session"]);
      expect(options.completeness, PluginSessionOptionsCompleteness.complete);
      expect(options.commands.single.name, "review");
      expect(options.agents.map((agent) => agent.name), ["Agent", "Plan"]);
      final provider = options.providers.providers.single;
      expect(provider.id, "copilot");
      expect(provider.defaultModelID, "gpt-5.4");
      expect(provider.models.map((model) => model.id), ["gpt-5.4", "claude-sonnet-4.5"]);
      expect(provider.models.first.variants, ["low", "high"]);
      expect(configurations.processDefaults.modelId, "gpt-5.4");
      expect(configurations.processDefaults.providerId, "copilot");

      await service.getSessionOptions(discoveryMode: PluginSessionOptionsDiscoveryMode.reuse);
      expect(repository.createdDirectories, ["/project"]);
    });

    test("applies model, mode, and reasoning through standard config writes", () async {
      service.captureSessionConfig(_sessionResult(), sessionId: "session", fromNewSession: true);
      final configRepository = _ConfigRepository(
        results: [
          _sessionResult(model: "claude-sonnet-4.5"),
          _sessionResult(model: "claude-sonnet-4.5", mode: "plan"),
          _sessionResult(model: "claude-sonnet-4.5", mode: "plan", thoughtLevel: "high"),
        ],
      );

      await service.applyTurnSelection(
        configRepository: configRepository,
        sessionId: "session",
        model: (providerID: "copilot", modelID: "claude-sonnet-4.5"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "Plan",
      );

      expect(configRepository.writes, [
        (configId: "model", value: "claude-sonnet-4.5"),
        (configId: "mode", value: "plan"),
        (configId: "reasoning_effort", value: "high"),
      ]);
      expect(configurations.snapshotForSession(sessionId: "session").modelId, "claude-sonnet-4.5");
    });
  });
}

AcpNewSessionResult _sessionResult({
  String model = "gpt-5.4",
  String mode = "agent",
  String thoughtLevel = "low",
}) => AcpNewSessionResult.fromJson({
  "sessionId": "catalog-session",
  "configOptions": [
    _option(
      id: "model",
      category: "model",
      currentValue: model,
      values: const [("gpt-5.4", "GPT-5.4"), ("claude-sonnet-4.5", "Claude Sonnet 4.5")],
    ),
    _option(
      id: "mode",
      category: "mode",
      currentValue: mode,
      values: const [("agent", "Agent"), ("plan", "Plan")],
    ),
    _option(
      id: "reasoning_effort",
      category: "thought_level",
      currentValue: thoughtLevel,
      values: const [("low", "Low"), ("high", "High")],
    ),
    _option(
      id: "allow_all",
      category: "permissions",
      currentValue: "no",
      values: const [("no", "No"), ("yes", "Yes")],
    ),
  ],
});

Map<String, Object?> _option({
  required String id,
  required String category,
  required String currentValue,
  required List<(String, String)> values,
}) => {
  "id": id,
  "category": category,
  "currentValue": currentValue,
  "options": [
    for (final value in values) {"value": value.$1, "name": value.$2},
  ],
};

class _CatalogRepository({required final AcpNewSessionResult result}) implements CopilotCatalogRepository {
  final List<String> createdDirectories = [];
  final List<String> closedSessions = [];

  @override
  List<PluginCommand> get commands => const [];

  @override
  bool get hasCommandSnapshot => false;

  @override
  Future<void> open({required Duration timeout}) async {}

  @override
  Future<AcpNewSessionResult> createSession({required String cwd, required Duration timeout}) async {
    createdDirectories.add(cwd);
    return result;
  }

  @override
  Future<void> closeSession({required String sessionId, required Duration timeout}) async {
    closedSessions.add(sessionId);
  }

  @override
  Future<void> waitForCommandSnapshot({required Duration timeout}) async {}

  @override
  Future<void> settle() async {}

  @override
  Future<void> dispose() async {}
}

class _ConfigRepository({required final List<AcpNewSessionResult?> results}) implements AcpSessionConfigRepository {
  final List<({String configId, String value})> writes = [];
  var _index = 0;

  @override
  Future<AcpNewSessionResult?> setConfigOption({
    required String sessionId,
    required String configId,
    required String value,
  }) async {
    writes.add((configId: configId, value: value));
    return results[_index++];
  }
}
