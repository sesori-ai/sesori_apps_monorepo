import "package:args/command_runner.dart" as cli;
import "package:test/test.dart";

import "../../../bin/bridge.dart";

void main() {
  test("run command registers every plugin option and no selector", () {
    final options = RunCommand().argParser.options;

    expect(options.keys, containsAll(["opencode-bin", "codex-bin", "cursor-bin"]));
    expect(options, isNot(contains("plugin")));
  });

  test("run command rejects an unknown import id before startup", () async {
    final runner = cli.CommandRunner<void>("sesori-bridge", "test")..addCommand(RunCommand());

    await expectLater(
      runner.run(const ["run", "--import-plugin", "bogus"]),
      throwsA(
        isA<cli.UsageException>().having(
          (error) => error.message,
          "message",
          contains('unknown plugin "bogus"'),
        ),
      ),
    );
  });

  test("run command treats the removed plugin selector as unknown", () async {
    final runner = cli.CommandRunner<void>("sesori-bridge", "test")..addCommand(RunCommand());

    await expectLater(
      runner.run(const ["run", "--plugin", "opencode"]),
      throwsA(
        isA<cli.UsageException>().having((error) => error.message, "message", contains('Could not find an option')),
      ),
    );
  });
}
