import "dart:async";
import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

class _FakeCommandExecutor({final CommandResult? result, final Object? error}) implements CommandExecutor {
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

class const _SemverManifest() extends RuntimeManifest {
  @override
  String get runtimeId => "opencode";

  @override
  String get displayName => "OpenCode";

  @override
  String get installDocsUrl => "https://opencode.ai/docs#install";

  @override
  String get pathExecutableName => "opencode";

  @override
  String get binaryFileName => "opencode";

  @override
  RuntimeVersion get minPathVersion => SemanticRuntimeVersion.parse(value: "1.0.0");

  @override
  RuntimeVersion get bundledVersion => SemanticRuntimeVersion.parse(value: "1.17.9");

  @override
  RuntimeVersion? parseVersion({required String value}) => SemanticRuntimeVersion.tryParse(value: value);

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) => null;

  @override
  String downloadUrlFor({required RuntimeAsset asset}) => "https://example.test/${asset.assetName}";
}

void main() {
  group("RuntimeVersionValidator.detectVersion", () {
    Future<RuntimeVersion?> detect(_FakeCommandExecutor executor) {
      return RuntimeVersionValidator(
        commandExecutor: executor,
        manifest: const _SemverManifest(),
      ).detectVersion(
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
          stderr: () => CapturingStdout(lines: stderrLines),
        );
      } finally {
        Log.level = originalLevel;
      }

      expect(stderrLines.join("\n"), isNot(contains(secretOutput)));
    });

    test("parses version output through the manifest's own scheme", () {
      final validator = RuntimeVersionValidator(
        commandExecutor: _FakeCommandExecutor(),
        manifest: const _SemverManifest(),
      );

      expect(validator.parseVersionOutput(output: "codex-cli v0.144.5")?.raw, "0.144.5");
    });
  });

  group("RuntimeVersionValidator.probe", () {
    Future<RuntimeProbeOutcome> probe(_FakeCommandExecutor executor) {
      return RuntimeVersionValidator(
        commandExecutor: executor,
        manifest: const _SemverManifest(),
      ).probe(
        executable: "opencode",
        environment: const {"PATH": "/usr/bin"},
      );
    }

    test("distinguishes successful, non-zero, and unrecognized output", () async {
      expect(
        await probe(
          _FakeCommandExecutor(
            result: const CommandResult(exitCode: 0, stdout: "1.17.9", stderr: ""),
          ),
        ),
        isA<RuntimeProbeReady>().having((outcome) => outcome.version.raw, "version", "1.17.9"),
      );
      expect(
        await probe(
          _FakeCommandExecutor(
            result: const CommandResult(exitCode: 9, stdout: "", stderr: ""),
          ),
        ),
        isA<RuntimeProbeNonZeroExit>().having((outcome) => outcome.exitCode, "exitCode", 9),
      );
      expect(
        await probe(
          _FakeCommandExecutor(
            result: const CommandResult(exitCode: 0, stdout: "unknown", stderr: ""),
          ),
        ),
        isA<RuntimeProbeUnrecognized>(),
      );
    });

    test("distinguishes missing, timeout, and other failures", () async {
      expect(
        await probe(_FakeCommandExecutor(error: const ProcessException("opencode", ["--version"]))),
        isA<RuntimeProbeMissing>(),
      );
      expect(
        await probe(_FakeCommandExecutor(error: TimeoutException("timed out"))),
        isA<RuntimeProbeTimedOut>(),
      );
      expect(
        await probe(_FakeCommandExecutor(error: StateError("failed"))),
        isA<RuntimeProbeFailed>(),
      );
    });

    test("includes the attempted executable in unexpected failure logs", () async {
      final stderrLines = <String>[];
      final originalLevel = Log.level;
      Log.level = LogLevel.warning;
      try {
        await IOOverrides.runZoned(
          () => probe(_FakeCommandExecutor(error: StateError("failed"))),
          stderr: () => CapturingStdout(lines: stderrLines),
        );
      } finally {
        Log.level = originalLevel;
      }

      expect(stderrLines.join("\n"), contains("opencode --version"));
    });

    test("logs a recovered timeout with the attempted executable", () async {
      final stderrLines = <String>[];
      final originalLevel = Log.level;
      Log.level = LogLevel.warning;
      try {
        await IOOverrides.runZoned(
          () => probe(_FakeCommandExecutor(error: TimeoutException("timed out"))),
          stderr: () => CapturingStdout(lines: stderrLines),
        );
      } finally {
        Log.level = originalLevel;
      }

      expect(stderrLines.join("\n"), contains("opencode --version"));
    });

    test("logs nonzero and unrecognized probe outcomes at debug level", () async {
      final stderrLines = <String>[];
      final originalLevel = Log.level;
      Log.level = LogLevel.debug;
      try {
        await IOOverrides.runZoned(
          () async {
            await probe(
              _FakeCommandExecutor(
                result: const CommandResult(exitCode: 7, stdout: "", stderr: ""),
              ),
            );
            await probe(
              _FakeCommandExecutor(
                result: const CommandResult(exitCode: 0, stdout: "unknown", stderr: ""),
              ),
            );
          },
          stderr: () => CapturingStdout(lines: stderrLines),
        );
      } finally {
        Log.level = originalLevel;
      }

      final output = stderrLines.join("\n");
      expect(output, contains("opencode --version"));
      expect(output, contains("exited 7"));
      expect(output, contains("unrecognized version"));
    });
  });
}
