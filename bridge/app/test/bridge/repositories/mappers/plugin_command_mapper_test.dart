import "package:sesori_bridge/src/bridge/repositories/mappers/plugin_command_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PluginCommandMapping.toSharedCommandInfo()", () {
    test("maps command fields and strips template", () {
      const command = PluginCommand(
        name: "review",
        template: "/review {{input}}",
        hints: ["file.dart"],
        description: "Review changes",
        agent: "reviewer",
        model: "gpt-5",
        provider: "openai",
        source: PluginCommandSource.command,
        subtask: true,
      );

      expect(
        command.toSharedCommandInfo(),
        equals(
          const CommandInfo(
            name: "review",
            template: null,
            hints: ["file.dart"],
            description: "Review changes",
            agent: "reviewer",
            model: "gpt-5",
            provider: "openai",
            source: CommandSource.command,
            subtask: true,
          ),
        ),
      );
    });
  });
}
