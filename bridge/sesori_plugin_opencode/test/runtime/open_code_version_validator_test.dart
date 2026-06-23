import "package:opencode_plugin/src/runtime/open_code_version_validator.dart";
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
  group("OpenCodeVersionValidator.detectVersion", () {
    Future<SemanticVersion?> detect(_FakeCommandExecutor executor) {
      return OpenCodeVersionValidator(commandExecutor: executor).detectVersion(
        executable: "opencode",
        environment: const {"PATH": "/usr/bin"},
      );
    }

    test("parses a bare version string", () async {
      final version = await detect(_FakeCommandExecutor(result: const CommandResult(exitCode: 0, stdout: "1.17.9\n", stderr: "")));
      expect(version?.toString(), equals("1.17.9"));
    });

    test("parses a version embedded in prefixed output", () async {
      final version = await detect(_FakeCommandExecutor(result: const CommandResult(exitCode: 0, stdout: "opencode 1.2.3", stderr: "")));
      expect(version?.toString(), equals("1.2.3"));
    });

    test("runs '<bin> --version'", () async {
      final executor = _FakeCommandExecutor(result: const CommandResult(exitCode: 0, stdout: "1.0.0", stderr: ""));
      await detect(executor);
      expect(executor.ranExecutable, equals("opencode"));
      expect(executor.ranArguments, equals(const ["--version"]));
    });

    test("returns null on a non-zero exit", () async {
      final version = await detect(_FakeCommandExecutor(result: const CommandResult(exitCode: 1, stdout: "", stderr: "boom")));
      expect(version, isNull);
    });

    test("returns null when the binary cannot be launched", () async {
      final version = await detect(_FakeCommandExecutor(error: StateError("ENOENT")));
      expect(version, isNull);
    });

    test("returns null when the output has no parseable version", () async {
      final version = await detect(_FakeCommandExecutor(result: const CommandResult(exitCode: 0, stdout: "not a version", stderr: "")));
      expect(version, isNull);
    });
  });
}
