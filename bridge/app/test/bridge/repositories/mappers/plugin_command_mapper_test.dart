import "package:sesori_bridge/src/repositories/mappers/plugin_command_mapper.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("a plugin-named invocation drops the bridge's worktree note from its arguments", () {
    final note = buildWorktreeSystemContext(worktreePath: "/fixture/worktree", baseBranch: "main");
    PluginCommandInvocation named({required String? arguments}) =>
        PluginCommandInvocation(name: "fixture-greeter", source: PluginCommandSource.skill, arguments: arguments);

    expect(
      named(arguments: "${note}greet the team").toShared(),
      const CommandInvocation(name: "fixture-greeter", source: CommandSource.skill, arguments: "greet the team"),
    );
    expect(named(arguments: note).toShared().arguments, isNull);
    expect(named(arguments: null).toShared().arguments, isNull);
  });

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
