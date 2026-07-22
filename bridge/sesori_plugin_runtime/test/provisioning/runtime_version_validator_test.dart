import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

class _FakeCommandExecutor implements CommandExecutor {
  _FakeCommandExecutor({this.result, this.error});

  final CommandResult? result;
  final Object? error;
  String? ranExecutable;
  List<String>? ranArguments;

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    ranExecutable = executable;
    ranArguments = arguments;
    if (error != null) {
      throw error!;
    }
    return result!;
  }
}

void main() {
  group("RuntimeVersionValidator.detectVersion", () {
    Future<SemanticVersion?> detect(_FakeCommandExecutor executor) {
      return RuntimeVersionValidator(commandExecutor: executor, runtimeId: "opencode").detectVersion(
        executable: "opencode",
        environment: const {"PATH": "/usr/bin"},
      );
    }

    test("parses a bare version string", () async {
      final version = await detect(
        _FakeCommandExecutor(
          result: const CommandResult(exitCode: 0, stdout: "1.17.9\n", stderr: ""),
        ),
      );
      expect(version?.toString(), equals("1.17.9"));
    });

    test("parses a version embedded in prefixed output", () async {
      final version = await detect(
        _FakeCommandExecutor(
          result: const CommandResult(exitCode: 0, stdout: "opencode 1.2.3", stderr: ""),
        ),
      );
      expect(version?.toString(), equals("1.2.3"));
    });

    test("strips a leading 'v' from the version token", () async {
      final version = await detect(
        _FakeCommandExecutor(
          result: const CommandResult(exitCode: 0, stdout: "v1.17.9\n", stderr: ""),
        ),
      );
      expect(version?.toString(), equals("1.17.9"));
    });

    test("runs '<bin> --version'", () async {
      final executor = _FakeCommandExecutor(
        result: const CommandResult(exitCode: 0, stdout: "1.0.0", stderr: ""),
      );
      await detect(executor);
      expect(executor.ranExecutable, equals("opencode"));
      expect(executor.ranArguments, equals(const ["--version"]));
    });

    test("returns null on a non-zero exit", () async {
      final version = await detect(
        _FakeCommandExecutor(
          result: const CommandResult(exitCode: 1, stdout: "", stderr: "boom"),
        ),
      );
      expect(version, isNull);
    });

    test("returns null when the binary cannot be launched", () async {
      final version = await detect(_FakeCommandExecutor(error: StateError("ENOENT")));
      expect(version, isNull);
    });

    test("returns null when the output has no parseable version", () async {
      final version = await detect(
        _FakeCommandExecutor(
          result: const CommandResult(exitCode: 0, stdout: "not a version", stderr: ""),
        ),
      );
      expect(version, isNull);
    });

    test("does not write unparseable probe output to logs", () async {
      const secretOutput = "account-secret-output";
      final stderrLines = <String>[];
      final originalLevel = Log.level;
      Log.level = LogLevel.debug;
      try {
        await IOOverrides.runZoned(
          () => detect(
            _FakeCommandExecutor(
              result: const CommandResult(exitCode: 0, stdout: secretOutput, stderr: ""),
            ),
          ),
          stderr: () => _CapturingStdout(stderrLines),
        );
      } finally {
        Log.level = originalLevel;
      }

      expect(stderrLines.join("\n"), isNot(contains(secretOutput)));
    });

    test("exposes the shared version-output parser", () {
      final validator = RuntimeVersionValidator(
        commandExecutor: _FakeCommandExecutor(),
        runtimeId: "codex",
      );

      expect(validator.parseVersionOutput(output: "codex-cli v0.144.5")?.toString(), "0.144.5");
    });
  });
}

class _CapturingStdout implements Stdout {
  _CapturingStdout(this.lines);

  final List<String> lines;

  @override
  void writeln([Object? object = ""]) {
    lines.add(object.toString());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
