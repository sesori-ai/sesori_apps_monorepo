import "package:acp_plugin/acp_plugin.dart";
import "package:cursor_plugin/src/models/cursor_catalog_models.dart";
import "package:cursor_plugin/src/services/cursor_catalog_service.dart";
import "package:cursor_plugin/src/services/cursor_command_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("CursorCommandService", () {
    late _FakeCursorCatalogService catalogService;
    late AcpCommandTracker commandTracker;
    late CursorCommandService service;

    setUp(() {
      catalogService = _FakeCursorCatalogService();
      commandTracker = AcpCommandTracker();
      service = CursorCommandService(
        catalogService: catalogService,
        commandTracker: commandTracker,
        launchDirectory: "/repo",
      );
    });

    test("primes the requested scope and synthesizes compact", () async {
      commandTracker.consume(
        _commandUpdate([
          {"name": "review"},
        ]),
      );

      final commands = await service.listCommands(projectId: "/project");

      expect(catalogService.scopes, ["/project"]);
      expect(commands.map((command) => command.name), ["review", "compact"]);
      expect(commands.last.source, PluginCommandSource.command);
    });

    test("uses the launch directory when no project is selected", () async {
      await service.listCommands(projectId: null);

      expect(catalogService.scopes, ["/repo"]);
    });

    test("does not duplicate a natively advertised compact command", () async {
      commandTracker.consume(
        _commandUpdate([
          {"name": "compact", "description": "Native compaction"},
        ]),
      );

      final commands = await service.listCommands(projectId: "/project");

      expect(commands, hasLength(1));
      expect(commands.single.description, "Native compaction");
    });

    test("translates compact to Cursor's summarize command", () {
      expect(service.backendCommandFor(command: "compact"), "summarize");
      expect(service.backendCommandFor(command: "review"), "review");
    });
  });
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

class _FakeCursorCatalogService implements CursorCatalogService {
  final List<String> scopes = [];

  @override
  Future<void> ensureCatalog({required String scope}) async {
    scopes.add(scope);
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
