import "package:args/command_runner.dart" as cli;
import "package:sesori_bridge/src/bridge/runtime/plugin_registry.dart";
import "package:test/test.dart";

import "../../../bin/bridge.dart";

void main() {
  test("run command rejects an import id that is not the selected plugin", () async {
    final selected = knownPlugins.firstWhere((plugin) => plugin.id == "opencode");
    final runner = cli.CommandRunner<void>("sesori-bridge", "test")
      ..addCommand(RunCommand(selectedPlugin: selected, selectionError: null));

    await expectLater(
      runner.run(const ["run", "--import-plugin", "codex"]),
      throwsA(
        isA<cli.UsageException>().having(
          (error) => error.message,
          "message",
          contains('selected plugin is "opencode"'),
        ),
      ),
    );
  });
}
