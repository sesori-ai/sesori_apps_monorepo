import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/platform/io_bridge_process_environment.dart";

void main() {
  group("IoBridgeProcessEnvironment", () {
    test("parses every NUL-terminated record after the marker and ignores shell noise", () async {
      final List<int> output = <int>[
        ...utf8.encode("login shell banner\nPATH=/noise/bin"),
        0,
        ...utf8.encode("BASH_FUNC_path%%=() {\nPATH=\$PATH:/injected\n}"),
        0,
        ...utf8.encode("PATH=/shell/bin:/base/bin:/non-\u00e9:relative"),
        0,
        ...utf8.encode("ANTHROPIC_BASE_URL=http://127.0.0.1:9/a=b"),
        0,
        ...utf8.encode("not-a-record"),
        0,
        ...utf8.encode("logout banner"),
      ];
      final Map<String, String>? environment = await IoBridgeProcessEnvironment.parseEnvironmentStream(
        stream: Stream<List<int>>.fromIterable(<List<int>>[
          output.sublist(0, 11),
          output.sublist(11, output.length - 5),
          output.sublist(output.length - 5),
        ]),
      );

      expect(environment, <String, String>{
        "BASH_FUNC_path%%": "() {\nPATH=\$PATH:/injected\n}",
        "PATH": "/shell/bin:/base/bin:/non-é:relative",
        "ANTHROPIC_BASE_URL": "http://127.0.0.1:9/a=b",
      });
    });

    test("discards an environment larger than the capture limit", () async {
      final Map<String, String>? environment = await IoBridgeProcessEnvironment.parseEnvironmentStream(
        stream: Stream<List<int>>.fromIterable(<List<int>>[
          <int>[...List<int>.filled(70 * 1024, 120), 0],
          <int>[0, ...utf8.encode("PATH=/shell/bin"), 0],
          <int>[...utf8.encode("LARGE="), ...List<int>.filled(70 * 1024, 120), 0],
          <int>[...utf8.encode("TAIL=drained"), 0],
        ]),
      );

      expect(environment, isNull);
    });

    test("coalesces concurrent and refreshes login-shell PATH resolutions", () async {
      var calls = 0;
      String? shell;
      List<String>? capturedArguments;
      final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
        isMacOS: true,
        baseEnvironment: const <String, String>{
          "HOME": "/home/test",
          "PATH": "/base/bin",
          "EXISTING_VARIABLE": "retained",
          "SHELL": "/bin/zsh",
        },
        runProcess:
            ({
              required String executable,
              required List<String> arguments,
              required Map<String, String>? environment,
              required Duration timeout,
            }) async {
              calls++;
              shell = executable;
              capturedArguments = List<String>.of(arguments);
              expect(environment, isNull);
              expect(timeout, const Duration(seconds: 5));
              return const LaunchEnvironmentProcessResult(
                exitCode: 0,
                environment: <String, String>{
                  "PATH": "/shell/bin:/base/bin:/non-é:relative",
                  "ANTHROPIC_BASE_URL": "http://127.0.0.1:9",
                  "ANTHROPIC_AUTH_TOKEN": "secret-token",
                  "HTTPS_PROXY": "http://proxy.test:8080",
                  "EXISTING_VARIABLE": "from-shell",
                  "PWD": "/probe/cwd",
                  "OLDPWD": "/probe/old",
                  "SHLVL": "2",
                  "_": "/usr/bin/env",
                  "AUTH_BACKEND_URL": "https://shell.test",
                },
                stderr: "",
              );
            },
        shellTimeout: const Duration(seconds: 5),
      );

      final List<Map<String, String>> concurrent = await Future.wait(<Future<Map<String, String>>>[
        environment.resolve(),
        environment.resolve(),
      ]);
      final Map<String, String> first = concurrent[0];
      final Map<String, String> second = concurrent[1];
      final Map<String, String> refreshed = await environment.resolve();

      expect(first, same(second));
      expect(refreshed, isNot(same(first)));
      expect(calls, 2);
      expect(shell, "/bin/zsh");
      expect(capturedArguments, ["-ilc", r"/usr/bin/printf '\000'; /usr/bin/env -0"]);
      expect(first, <String, String>{
        "PATH": "/shell/bin:/base/bin:/non-é",
        "ANTHROPIC_BASE_URL": "http://127.0.0.1:9",
        "ANTHROPIC_AUTH_TOKEN": "secret-token",
        "HTTPS_PROXY": "http://proxy.test:8080",
        "EXISTING_VARIABLE": "from-shell",
      });
      expect(() => first["PATH"] = "/changed", throwsUnsupportedError);
    });

    test("honors an executable configured login shell outside system paths", () async {
      if (Platform.isWindows) return;
      final String configuredShell = Platform.resolvedExecutable;
      String? invokedShell;
      final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
        isMacOS: true,
        baseEnvironment: <String, String>{
          "HOME": "/home/test",
          "PATH": "/base/bin",
          "SHELL": configuredShell,
        },
        runProcess:
            ({
              required String executable,
              required List<String> arguments,
              required Map<String, String>? environment,
              required Duration timeout,
            }) async {
              invokedShell = executable;
              return const LaunchEnvironmentProcessResult(
                exitCode: 0,
                environment: <String, String>{"PATH": "/custom/shell/bin"},
                stderr: "",
              );
            },
        shellTimeout: const Duration(seconds: 5),
      );

      final Map<String, String> resolved = await environment.resolve();

      expect(invokedShell, configuredShell);
      expect(resolved["PATH"], "/custom/shell/bin:/base/bin");
    });

    test("retries after a failed probe instead of caching the empty result", () async {
      var calls = 0;
      final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
        isMacOS: true,
        baseEnvironment: const <String, String>{"PATH": "/system/bin"},
        runProcess:
            ({
              required String executable,
              required List<String> arguments,
              required Map<String, String>? environment,
              required Duration timeout,
            }) async {
              calls++;
              if (calls == 1) {
                return const LaunchEnvironmentProcessResult(
                  exitCode: 1,
                  environment: <String, String>{"PATH": "/ignored/bin"},
                  stderr: "login shell unavailable",
                );
              }
              return const LaunchEnvironmentProcessResult(
                exitCode: 0,
                environment: <String, String>{"PATH": "/shell/bin", "SHELL_ONLY": "value"},
                stderr: "",
              );
            },
        shellTimeout: const Duration(seconds: 5),
      );

      final Map<String, String> first = await environment.resolve();
      final Map<String, String> second = await environment.resolve();

      expect(first, isEmpty);
      expect(second, <String, String>{"PATH": "/shell/bin:/system/bin", "SHELL_ONLY": "value"});
      expect(calls, 2);
    });

    test("does not override the inherited environment for a missing, empty or relative-only shell PATH", () async {
      for (final Map<String, String> shellEnvironment in const <Map<String, String>>[
        <String, String>{"OTHER": "value"},
        <String, String>{"PATH": "", "OTHER": "value"},
        <String, String>{"PATH": "relative/bin:./another", "OTHER": "value"},
      ]) {
        final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
          isMacOS: true,
          baseEnvironment: const <String, String>{"PATH": "/system/bin"},
          runProcess: ({
            required String executable,
            required List<String> arguments,
            required Map<String, String>? environment,
            required Duration timeout,
          }) async => LaunchEnvironmentProcessResult(exitCode: 0, environment: shellEnvironment, stderr: ""),
          shellTimeout: const Duration(seconds: 5),
        );

        expect(await environment.resolve(), isEmpty, reason: "$shellEnvironment");
      }
    });

    test("preserves the inherited environment when the probe throws or output is oversized", () async {
      final List<LaunchEnvironmentProcessRunner> failingRunners = <LaunchEnvironmentProcessRunner>[
        ({
          required String executable,
          required List<String> arguments,
          required Map<String, String>? environment,
          required Duration timeout,
        }) async => throw TimeoutException("login shell timed out"),
        ({
          required String executable,
          required List<String> arguments,
          required Map<String, String>? environment,
          required Duration timeout,
        }) async => const LaunchEnvironmentProcessResult(exitCode: 0, environment: null, stderr: ""),
      ];
      for (final LaunchEnvironmentProcessRunner runProcess in failingRunners) {
        final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
          isMacOS: true,
          baseEnvironment: const <String, String>{"PATH": "/system/bin"},
          runProcess: runProcess,
          shellTimeout: const Duration(seconds: 5),
        );

        expect(await environment.resolve(), isEmpty);
      }
    });

    test("logs imported variable names but never their values", () async {
      final _RecordingLogSink sink = _RecordingLogSink();
      setLogSink(sink: sink);
      addTearDown(() => setLogSink(sink: const StdoutLogSink()));
      final LogLevel previousLevel = logLevel;
      setLogLevel(LogLevel.trace);
      addTearDown(() => setLogLevel(previousLevel));
      final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
        isMacOS: true,
        baseEnvironment: const <String, String>{"PATH": "/system/bin"},
        runProcess:
            ({
              required String executable,
              required List<String> arguments,
              required Map<String, String>? environment,
              required Duration timeout,
            }) async => const LaunchEnvironmentProcessResult(
              exitCode: 0,
              environment: <String, String>{"PATH": "/shell/bin", "ANTHROPIC_AUTH_TOKEN": "secret-token-value"},
              stderr: "",
            ),
        shellTimeout: const Duration(seconds: 5),
      );

      final Map<String, String> resolved = await environment.resolve();

      expect(resolved["ANTHROPIC_AUTH_TOKEN"], "secret-token-value");
      final String logged = sink.records.map((LogRecord record) => record.formatted).join("\n");
      expect(logged, contains("ANTHROPIC_AUTH_TOKEN"));
      expect(logged, isNot(contains("secret-token-value")));
      expect(logged, isNot(contains("/shell/bin")));
    });

    test("does not rewrite non-macOS PATH separators or invoke a shell", () async {
      var calls = 0;
      final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
        isMacOS: false,
        baseEnvironment: const <String, String>{"PATH": r"C:\\Windows;C:\\Tools"},
        runProcess:
            ({
              required String executable,
              required List<String> arguments,
              required Map<String, String>? environment,
              required Duration timeout,
            }) async {
              calls++;
              return const LaunchEnvironmentProcessResult(exitCode: 0, environment: null, stderr: "");
            },
        shellTimeout: const Duration(seconds: 5),
      );

      final Map<String, String> resolved = await environment.resolve();

      expect(calls, 0);
      expect(resolved, isEmpty);
    });
  });
}

class _RecordingLogSink() implements LogSink {
  final List<LogRecord> records = <LogRecord>[];

  @override
  void write({required LogRecord record}) => records.add(record);

  @override
  Future<void> flush() async {}
}
