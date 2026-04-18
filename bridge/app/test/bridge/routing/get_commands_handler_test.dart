import "package:sesori_bridge/src/bridge/repositories/command_repository.dart";
import "package:sesori_bridge/src/bridge/routing/get_commands_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetCommandsHandler", () {
    late FakeBridgePlugin plugin;
    late GetCommandsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = GetCommandsHandler(
        commandRepository: CommandRepository(plugin: plugin),
      );
    });

    tearDown(() => plugin.close());

    test("canHandle POST /command", () {
      expect(handler.canHandle(makeRequest("POST", "/command")), isTrue);
    });

    test("maps commands through repository mapper", () async {
      plugin.commandsResult = [
        const PluginCommand(
          name: "review",
          template: "/review",
          hints: ["file.dart"],
          description: "Review changes",
          agent: "reviewer",
          model: "gpt-5",
          provider: "openai",
          source: PluginCommandSource.command,
          subtask: true,
        ),
      ];

      final response = await handler.handle(
        makeRequest("POST", "/command"),
        body: const ProjectIdRequest(projectId: "/repo"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastGetCommandsProjectId, equals("/repo"));
      expect(
        response,
        equals(
          const CommandListResponse(
            items: [
              CommandInfo(
                name: "review",
                hints: ["file.dart"],
                description: "Review changes",
                agent: "reviewer",
                model: "gpt-5",
                provider: "openai",
                source: CommandSource.command,
                subtask: true,
              ),
            ],
          ),
        ),
      );
    });
  });
}
