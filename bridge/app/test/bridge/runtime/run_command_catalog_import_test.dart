import "dart:io";

import "package:args/command_runner.dart" as cli;
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:test/test.dart";

import "../../../bin/bridge.dart";

void main() {
  test("run command registers every plugin option and no selector", () {
    final options = RunCommand().argParser.options;

    expect(
      options.keys,
      containsAll(["opencode-bin", "codex-bin", "copilot-bin", "cursor-bin", "deepseek-bin", "grok-bin"]),
    );
    expect(options["import-plugin"]?.hide, isTrue);
    expect(options, isNot(contains("plugin")));
  });

  test("run command warns once and ignores every deprecated import option", () async {
    final runner = cli.CommandRunner<void>("sesori-bridge", "test")..addCommand(RunCommand());
    final stdout = BufferingStdout();
    final stderr = BufferingStdout();

    await IOOverrides.runZoned(
      () => runner.run(
        const ["run", "--version", "--import-plugin", "bogus", "--import-plugin", "opencode"],
      ),
      stdout: () => stdout,
      stderr: () => stderr,
    );

    expect(stdout.text, isNotEmpty);
    expect(stderr.text, contains("--import-plugin option is deprecated and no longer does anything"));
    expect(stderr.text, contains("pulling to refresh"));
    expect(stderr.text, contains("Settings > Harnesses"));
    expect(RegExp("deprecated").allMatches(stderr.text), hasLength(1));
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
