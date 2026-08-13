import "package:acp_plugin/acp_plugin.dart";
import "package:cursor_plugin/src/models/cursor_catalog_models.dart";
import "package:cursor_plugin/src/services/cursor_catalog_service.dart";
import "package:cursor_plugin/src/services/cursor_session_options_service.dart";
import "package:cursor_plugin/src/trackers/cursor_catalog_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("CursorSessionOptionsService", () {
    late _FakeCursorCatalogService catalogService;
    late CursorCatalogTracker catalogTracker;
    late AcpCommandTracker commandTracker;
    late CursorSessionOptionsService service;

    setUp(() {
      catalogService = _FakeCursorCatalogService();
      catalogTracker = CursorCatalogTracker();
      commandTracker = AcpCommandTracker();
      service = CursorSessionOptionsService(
        catalogService: catalogService,
        catalogTracker: catalogTracker,
        commandTracker: commandTracker,
        launchDirectory: "/repo",
      );
    });

    test("legacy command discovery primes one scope and preserves compact translation", () async {
      commandTracker.consume(
        _commandUpdate([
          {"name": "review"},
        ]),
      );

      final commands = await service.listCommands(projectId: "/project");

      expect(catalogService.reusedScopes, ["/project"]);
      expect(commands.map((command) => command.name), ["review", "compact"]);
      expect(service.backendCommandFor(command: "compact"), "summarize");
      expect(service.backendCommandFor(command: "review"), "review");
    });

    test("reuse performs one catalog ensure and returns plugin-global coherent output", () async {
      _seedCompleteCatalog(catalogTracker);
      commandTracker.consume(
        _commandUpdate([
          {"name": "review"},
        ]),
      );

      final first = await service.getSessionOptions(
        projectId: "/project-a",
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      );
      final second = await service.getSessionOptions(
        projectId: "/project-b",
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      );

      expect(catalogService.reusedScopes, ["/project-a", "/project-b"]);
      final firstOptions = (first as PluginSessionOptionsDiscoveryObserved).options;
      final secondOptions = (second as PluginSessionOptionsDiscoveryObserved).options;
      expect(firstOptions, secondOptions);
      expect(firstOptions.completeness, PluginSessionOptionsCompleteness.complete);
      expect(firstOptions.agents.map((agent) => agent.name), ["Agent", "Plan"]);
      expect(firstOptions.providers.providers.single.models.single.id, "model");
      expect(firstOptions.commands.map((command) => command.name), ["review", "compact"]);
    });

    test("refresh uses one forced operation rather than bounded reuse", () async {
      _seedCompleteCatalog(catalogTracker);
      commandTracker.consume(_commandUpdate(const []));

      final result = await service.getSessionOptions(
        projectId: "/project",
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
      );

      expect(result, isA<PluginSessionOptionsDiscoveryObserved>());
      expect(catalogService.reusedScopes, isEmpty);
      expect(catalogService.refreshedScopes, ["/project"]);
    });

    test("forced discovery failure is failed, not stale observed partial", () async {
      _seedCompleteCatalog(catalogTracker);
      commandTracker.consume(_commandUpdate(const []));
      catalogService.refreshSucceeds = false;

      final result = await service.getSessionOptions(
        projectId: "/project",
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
      );

      expect(result, isA<PluginSessionOptionsDiscoveryFailed>());
      expect(catalogService.refreshedScopes, ["/project"]);
    });

    test("uses the launch directory when a legacy command read has no project", () async {
      await service.listCommands(projectId: null);

      expect(catalogService.reusedScopes, ["/repo"]);
    });
  });
}

void _seedCompleteCatalog(CursorCatalogTracker tracker) {
  tracker.applySnapshot(
    snapshot: CursorCatalogSnapshot(
      modelConfigId: "model-picker",
      models: const [CursorCatalogOption(value: "model", name: "Model", description: null)],
      loadedModelId: "model",
      modeConfigId: "mode-picker",
      modes: const [
        CursorCatalogOption(value: "agent", name: "Agent", description: "Acts"),
        CursorCatalogOption(value: "plan", name: "Plan", description: "Plans"),
      ],
      loadedModeId: "agent",
      thoughtLevel: CursorThoughtLevelSnapshot(
        configId: "effort",
        variants: const ["medium", "high"],
        defaultValue: "medium",
      ),
    ),
    fromNewSession: true,
    thoughtLevelModelId: null,
    captureThoughtLevelDefault: true,
  );
}

AcpNotification _commandUpdate(List<Map<String, dynamic>> commands) => AcpNotification(
  method: "session/update",
  params: {
    "sessionId": "session",
    "update": {
      "sessionUpdate": "available_commands_update",
      "availableCommands": commands,
    },
  },
);

class _FakeCursorCatalogService() implements CursorCatalogService {
  final List<String> reusedScopes = [];
  final List<String> refreshedScopes = [];
  bool refreshSucceeds = true;

  @override
  Future<void> ensureCatalog({required String scope}) async {
    reusedScopes.add(scope);
  }

  @override
  Future<bool> refreshCatalog({required String scope}) async {
    refreshedScopes.add(scope);
    return refreshSucceeds;
  }

  @override
  CursorCatalogCaptureResult captureSessionConfig({
    required AcpNewSessionResult result,
    required bool fromNewSession,
    required String? thoughtLevelModelId,
    required bool captureThoughtLevelDefault,
  }) => throw UnimplementedError();

  @override
  Future<void> dispose() async {}
}
