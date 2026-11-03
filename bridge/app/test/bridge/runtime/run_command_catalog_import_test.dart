import "package:args/command_runner.dart" as cli;
import "package:test/test.dart";

import "../../../bin/bridge.dart";

void main() {
  test("run command registers every plugin option and no selector", () {
    final options = RunCommand().argParser.options;

    expect(
      options.keys,
      containsAll([
        "opencode-bin",
        "antigravity-bin",
        "codex-bin",
        "copilot-bin",
        "cursor-bin",
        "deepseek-bin",
        "grok-bin",
      ]),
    );
    expect(options, isNot(contains("plugin")));
    expect(options, isNot(contains("import-plugin")));
  });

  for (final removed in const ["--plugin", "--import-plugin"]) {
    test("run command treats the removed $removed option as unknown", () async {
      final runner = cli.CommandRunner<void>("sesori-bridge", "test")..addCommand(RunCommand());

      await expectLater(
        runner.run(["run", removed, "opencode"]),
        throwsA(
          isA<cli.UsageException>().having((error) => error.message, "message", contains('Could not find an option')),
        ),
      );
    });
  }
}
