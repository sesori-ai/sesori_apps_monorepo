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
      final LaunchShellEnvironment environment = await IoBridgeProcessEnvironment.parseEnvironmentStream(
        stream: Stream<List<int>>.fromIterable(<List<int>>[
          output.sublist(0, 11),
          output.sublist(11, output.length - 5),
          output.sublist(output.length - 5),
        ]),
      );

      expect(
        environment,
        isA<CompleteLaunchShellEnvironment>().having(
          (CompleteLaunchShellEnvironment environment) => environment.variables,
          "variables",
          <String, String>{
            "BASH_FUNC_path%%": "() {\nPATH=\$PATH:/injected\n}",
            "PATH": "/shell/bin:/base/bin:/non-é:relative",
            "ANTHROPIC_BASE_URL": "http://127.0.0.1:9/a=b",
          },
        ),
      );
    });

    test("keeps only the PATH record of an environment larger than the capture limit", () async {
      final List<List<int>> beforePath = <List<int>>[
        <int>[...utf8.encode("login banner "), ...List<int>.filled(70 * 1024, 120), 0],
        <int>[...utf8.encode("LARGE="), ...List<int>.filled(70 * 1024, 120), 0],
        for (int index = 0; index < 40; index++)
          <int>[...utf8.encode("FILLER_$index="), ...List<int>.filled(2048, 121), 0],
      ];
      for (final List<List<int>> chunks in <List<List<int>>>[
        <List<int>>[
          ...beforePath,
          <int>[...utf8.encode("PATH=/shell/bin"), 0],
        ],
        <List<int>>[
          <int>[0, ...utf8.encode("PATH=/shell/bin"), 0],
          ...beforePath.skip(1),
        ],
      ]) {
        final LaunchShellEnvironment environment = await IoBridgeProcessEnvironment.parseEnvironmentStream(
          stream: Stream<List<int>>.fromIterable(chunks),
        );

        expect(
          environment,
          isA<OversizedLaunchShellEnvironment>().having(
            (OversizedLaunchShellEnvironment environment) => environment.path,
            "path",
            "/shell/bin",
          ),
        );
      }
    });

    test("imports only PATH from an oversized login-shell environment", () async {
      final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
        platform: LoginShellPlatform.macOS,
        baseEnvironment: const <String, String>{"PATH": "/system/bin"},
        runProcess:
            ({
              required String executable,
              required List<String> arguments,
              required Map<String, String>? environment,
              required Duration timeout,
            }) async => const LaunchEnvironmentProcessResult(
              exitCode: 0,
              environment: OversizedLaunchShellEnvironment(path: "/shell/bin"),
              stderr: "",
            ),
        shellTimeout: const Duration(seconds: 5),
        readPasswdFile: () => null,
      );

      expect(await environment.resolve(), <String, String>{"PATH": "/shell/bin:/system/bin"});
    });

    for (final (LoginShellPlatform platform, String configuredShell, String command)
        in <(LoginShellPlatform, String, String)>[
          (LoginShellPlatform.macOS, "/bin/zsh", r"/usr/bin/printf '\000'; /usr/bin/env -0"),
          (LoginShellPlatform.linux, "/bin/sh", r"/usr/bin/env printf '\000'; /usr/bin/env -0"),
        ]) {
      test("imports the ${platform.name} login-shell environment, coalescing concurrent resolutions", () async {
        var calls = 0;
        String? shell;
        List<String>? capturedArguments;
        final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
          platform: platform,
          baseEnvironment: <String, String>{
            "HOME": "/home/test",
            "PATH": "/base/bin",
            "EXISTING_VARIABLE": "retained",
            "SHELL": configuredShell,
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
                expect(environment, <String, String>{"SESORI_RESOLVING_ENVIRONMENT": "1"});
                expect(timeout, const Duration(seconds: 5));
                return const LaunchEnvironmentProcessResult(
                  exitCode: 0,
                  environment: CompleteLaunchShellEnvironment(
                    variables: <String, String>{
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
                      "SESORI_RESOLVING_ENVIRONMENT": "1",
                    },
                  ),
                  stderr: "",
                );
              },
          shellTimeout: const Duration(seconds: 5),
          readPasswdFile: () => null,
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
        expect(shell, configuredShell);
        expect(capturedArguments, ["-ilc", command]);
        expect(first, <String, String>{
          "PATH": "/shell/bin:/base/bin:/non-é",
          "ANTHROPIC_BASE_URL": "http://127.0.0.1:9",
          "ANTHROPIC_AUTH_TOKEN": "secret-token",
          "HTTPS_PROXY": "http://proxy.test:8080",
          "EXISTING_VARIABLE": "from-shell",
        });
        expect(() => first["PATH"] = "/changed", throwsUnsupportedError);
      });
    }

    test("maps each login shell to its interactive login flags", () {
      const String command = "printf x";
      for (final (String shell, List<String> expected) in <(String, List<String>)>[
        ("/bin/zsh", <String>["-ilc", command]),
        ("/bin/bash", <String>["-ilc", command]),
        ("/bin/sh", <String>["-ilc", command]),
        ("/usr/bin/fish", <String>["-ilc", command]),
        ("/bin/csh", <String>["-ic", command]),
        ("/usr/local/bin/tcsh", <String>["-ic", command]),
        ("/opt/homebrew/bin/nu", <String>["-l", "-i", "-c", command]),
        ("/home/me/.local/bin/xonsh", <String>["-l", "-i", "-c", command]),
        ("/usr/local/bin/pwsh", <String>["-Login", "-NonInteractive", "-Command", command]),
        ("/snap/bin/pwsh-preview", <String>["-Login", "-NonInteractive", "-Command", command]),
        ("/opt/nu/bin/zsh", <String>["-ilc", command]),
        ("/opt/xonsh/bin/bash", <String>["-ilc", command]),
        ("/home/me/bin/nush", <String>["-ilc", command]),
        ("/home/me/bin/pwsh7", <String>["-ilc", command]),
      ]) {
        expect(
          IoBridgeProcessEnvironment.loginShellArguments(shell: shell, command: command),
          expected,
          reason: shell,
        );
      }
    });

    test("gives xonsh a raw-string marker and every other shell the plain one", () {
      for (final (String shell, LoginShellPlatform platform, String expected) in <(String, LoginShellPlatform, String)>[
        ("/bin/zsh", LoginShellPlatform.macOS, r"/usr/bin/printf '\000'; /usr/bin/env -0"),
        ("/usr/local/bin/pwsh", LoginShellPlatform.macOS, r"/usr/bin/printf '\000'; /usr/bin/env -0"),
        ("/usr/bin/pwsh", LoginShellPlatform.linux, r"/usr/bin/env printf '\000'; /usr/bin/env -0"),
        ("/opt/homebrew/bin/xonsh", LoginShellPlatform.macOS, r"/usr/bin/printf r'\000'; /usr/bin/env -0"),
        ("/usr/bin/xonsh", LoginShellPlatform.linux, r"/usr/bin/env printf r'\000'; /usr/bin/env -0"),
        ("/opt/xonsh/bin/bash", LoginShellPlatform.linux, r"/usr/bin/env printf '\000'; /usr/bin/env -0"),
      ]) {
        expect(
          IoBridgeProcessEnvironment.probeCommand(shell: shell, platform: platform),
          expected,
          reason: "$shell on ${platform.name}",
        );
      }
    });

    test("probes a configured xonsh login shell with its own flags and marker", () async {
      if (Platform.isWindows) return;
      final Directory directory = await Directory.systemTemp.createTemp("sesori_xonsh_probe_");
      addTearDown(() => directory.delete(recursive: true));
      final File xonsh = File("${directory.path}/xonsh");
      await xonsh.writeAsString("#!/bin/sh\n");
      await Process.run("chmod", <String>["+x", xonsh.path]);
      List<String>? capturedArguments;
      final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
        platform: LoginShellPlatform.linux,
        baseEnvironment: <String, String>{"PATH": "/base/bin", "SHELL": xonsh.path},
        runProcess:
            ({
              required String executable,
              required List<String> arguments,
              required Map<String, String>? environment,
              required Duration timeout,
            }) async {
              expect(executable, xonsh.path);
              capturedArguments = List<String>.of(arguments);
              return const LaunchEnvironmentProcessResult(
                exitCode: 0,
                environment: CompleteLaunchShellEnvironment(variables: <String, String>{"PATH": "/xonsh/bin"}),
                stderr: "",
              );
            },
        shellTimeout: const Duration(seconds: 5),
        readPasswdFile: () => null,
      );

      final Map<String, String> resolved = await environment.resolve();

      expect(capturedArguments, <String>["-l", "-i", "-c", r"/usr/bin/env printf r'\000'; /usr/bin/env -0"]);
      expect(resolved["PATH"], "/xonsh/bin:/base/bin");
    });

    test("falls back to the Linux passwd shell, then /bin/sh, without a usable SHELL", () async {
      if (Platform.isWindows) return;
      final String passwdShell = Platform.resolvedExecutable;
      final String passwd = <String>[
        "root:x:0:0:root:/root:/bin/bash",
        "tester:x:1000:1000:Tester,,,:/home/tester:$passwdShell",
      ].join("\n");
      for (final (Map<String, String> baseEnvironment, String? passwdFile, String expectedShell)
          in <(Map<String, String>, String?, String)>[
            (<String, String>{"USER": "tester"}, passwd, passwdShell),
            (<String, String>{"LOGNAME": "tester", "SHELL": "/missing/shell"}, passwd, passwdShell),
            (<String, String>{"USER": "tester", "SHELL": "relative/shell"}, passwd, passwdShell),
            (<String, String>{"USER": "someone-else"}, passwd, "/bin/sh"),
            (<String, String>{}, passwd, "/bin/sh"),
            (<String, String>{"USER": "tester"}, null, "/bin/sh"),
            (<String, String>{"USER": "tester"}, "tester:x:1000:1000::/home/tester:/missing/shell", "/bin/sh"),
          ]) {
        String? invokedShell;
        final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
          platform: LoginShellPlatform.linux,
          baseEnvironment: <String, String>{"PATH": "/usr/bin", ...baseEnvironment},
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
                  environment: CompleteLaunchShellEnvironment(variables: <String, String>{"PATH": "/shell/bin"}),
                  stderr: "",
                );
              },
          shellTimeout: const Duration(seconds: 5),
          readPasswdFile: () => passwdFile,
        );

        expect(await environment.resolve(), <String, String>{"PATH": "/shell/bin:/usr/bin"});
        expect(invokedShell, expectedShell, reason: "$baseEnvironment");
      }
    });

    test("falls back to /bin/zsh on macOS without consulting passwd", () async {
      var passwdReads = 0;
      String? invokedShell;
      final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
        platform: LoginShellPlatform.macOS,
        baseEnvironment: const <String, String>{"PATH": "/usr/bin", "USER": "tester"},
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
                environment: CompleteLaunchShellEnvironment(variables: <String, String>{"PATH": "/shell/bin"}),
                stderr: "",
              );
            },
        shellTimeout: const Duration(seconds: 5),
        readPasswdFile: () {
          passwdReads++;
          return null;
        },
      );

      await environment.resolve();

      expect(invokedShell, "/bin/zsh");
      expect(passwdReads, 0);
    });

    test("honors an executable configured login shell outside system paths", () async {
      if (Platform.isWindows) return;
      final String configuredShell = Platform.resolvedExecutable;
      String? invokedShell;
      final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
        platform: LoginShellPlatform.macOS,
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
                environment: CompleteLaunchShellEnvironment(variables: <String, String>{"PATH": "/custom/shell/bin"}),
                stderr: "",
              );
            },
        shellTimeout: const Duration(seconds: 5),
        readPasswdFile: () => null,
      );

      final Map<String, String> resolved = await environment.resolve();

      expect(invokedShell, configuredShell);
      expect(resolved["PATH"], "/custom/shell/bin:/base/bin");
    });

    test("retries after a failed probe instead of caching the empty result", () async {
      var calls = 0;
      final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
        platform: LoginShellPlatform.macOS,
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
                  environment: CompleteLaunchShellEnvironment(variables: <String, String>{"PATH": "/ignored/bin"}),
                  stderr: "login shell unavailable",
                );
              }
              return const LaunchEnvironmentProcessResult(
                exitCode: 0,
                environment: CompleteLaunchShellEnvironment(
                  variables: <String, String>{"PATH": "/shell/bin", "SHELL_ONLY": "value"},
                ),
                stderr: "",
              );
            },
        shellTimeout: const Duration(seconds: 5),
        readPasswdFile: () => null,
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
          platform: LoginShellPlatform.macOS,
          baseEnvironment: const <String, String>{"PATH": "/system/bin"},
          runProcess:
              ({
                required String executable,
                required List<String> arguments,
                required Map<String, String>? environment,
                required Duration timeout,
              }) async => LaunchEnvironmentProcessResult(
                exitCode: 0,
                environment: CompleteLaunchShellEnvironment(variables: shellEnvironment),
                stderr: "",
              ),
          shellTimeout: const Duration(seconds: 5),
          readPasswdFile: () => null,
        );

        expect(await environment.resolve(), isEmpty, reason: "$shellEnvironment");
      }
    });

    test("preserves the inherited environment when the probe throws or an oversized output lacks PATH", () async {
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
        }) async => const LaunchEnvironmentProcessResult(
          exitCode: 0,
          environment: OversizedLaunchShellEnvironment(path: null),
          stderr: "",
        ),
      ];
      for (final LaunchEnvironmentProcessRunner runProcess in failingRunners) {
        final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
          platform: LoginShellPlatform.macOS,
          baseEnvironment: const <String, String>{"PATH": "/system/bin"},
          runProcess: runProcess,
          shellTimeout: const Duration(seconds: 5),
          readPasswdFile: () => null,
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
        platform: LoginShellPlatform.macOS,
        baseEnvironment: const <String, String>{"PATH": "/system/bin"},
        runProcess:
            ({
              required String executable,
              required List<String> arguments,
              required Map<String, String>? environment,
              required Duration timeout,
            }) async => const LaunchEnvironmentProcessResult(
              exitCode: 0,
              environment: CompleteLaunchShellEnvironment(
                variables: <String, String>{"PATH": "/shell/bin", "ANTHROPIC_AUTH_TOKEN": "secret-token-value"},
              ),
              stderr: "",
            ),
        shellTimeout: const Duration(seconds: 5),
        readPasswdFile: () => null,
      );

      final Map<String, String> resolved = await environment.resolve();

      expect(resolved["ANTHROPIC_AUTH_TOKEN"], "secret-token-value");
      final String logged = sink.records.map((LogRecord record) => record.formatted).join("\n");
      expect(logged, contains("ANTHROPIC_AUTH_TOKEN"));
      expect(logged, isNot(contains("secret-token-value")));
      expect(logged, isNot(contains("/shell/bin")));
    });

    test("does not rewrite Windows PATH separators or invoke a shell", () async {
      var calls = 0;
      final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
        platform: null,
        baseEnvironment: const <String, String>{"PATH": r"C:\\Windows;C:\\Tools"},
        runProcess:
            ({
              required String executable,
              required List<String> arguments,
              required Map<String, String>? environment,
              required Duration timeout,
            }) async {
              calls++;
              return const LaunchEnvironmentProcessResult(
                exitCode: 0,
                environment: CompleteLaunchShellEnvironment(variables: <String, String>{}),
                stderr: "",
              );
            },
        shellTimeout: const Duration(seconds: 5),
        readPasswdFile: () => null,
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
