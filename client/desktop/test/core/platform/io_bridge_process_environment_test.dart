import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/io_bridge_process_environment.dart";

void main() {
  group("IoBridgeProcessEnvironment", () {
    test("parses NUL-delimited output without losing PATH after oversized records", () async {
      final List<int> output = <int>[
        ...utf8.encode("BASH_FUNC_path%%=() {\nPATH=\$PATH:/injected\n}"),
        0,
        ...List<int>.filled(70 * 1024, 120),
        0,
        ...utf8.encode("PATH=/shell/bin:/base/bin:/non-\u00e9:relative"),
        0,
      ];
      final String? path = await IoBridgeProcessEnvironment.parsePathStream(
        stream: Stream<List<int>>.fromIterable(<List<int>>[
          output.sublist(0, 11),
          output.sublist(11, output.length - 5),
          output.sublist(output.length - 5),
        ]),
      );

      expect(path, "/shell/bin:/base/bin:/non-é:relative");
      expect(path, isNot(contains("/injected")));
    });

    test("resolves and caches a login-shell PATH without dropping valid Unicode entries", () async {
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
                path: "/shell/bin:/base/bin:/non-é:relative",
                stderr: "",
              );
            },
        shellTimeout: const Duration(seconds: 5),
      );

      final Map<String, String> first = await environment.resolve();
      final Map<String, String> second = await environment.resolve();

      expect(first, same(second));
      expect(calls, 1);
      expect(shell, "/bin/zsh");
      expect(capturedArguments, ["-ilc", "/usr/bin/env -0"]);
      expect(first["PATH"], "/shell/bin:/base/bin:/non-é");
      expect(first["PATH"], isNot(contains("/injected")));
      expect(first["EXISTING_VARIABLE"], isNull);
      expect(first["SECRET_FROM_SHELL"], isNull);
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
                path: "/custom/shell/bin",
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
                  path: null,
                  stderr: "login shell unavailable",
                );
              }
              return const LaunchEnvironmentProcessResult(
                exitCode: 0,
                path: "/shell/bin",
                stderr: "",
              );
            },
        shellTimeout: const Duration(seconds: 5),
      );

      final Map<String, String> first = await environment.resolve();
      final Map<String, String> second = await environment.resolve();

      expect(first, isEmpty);
      expect(second["PATH"], "/shell/bin:/system/bin");
      expect(calls, 2);
    });

    test("does not override the inherited environment for empty or relative-only shell PATH", () async {
      for (final String shellPath in const <String>["", "relative/bin:./another"]) {
        final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
          isMacOS: true,
          baseEnvironment: const <String, String>{"PATH": "/system/bin"},
          runProcess: ({
            required String executable,
            required List<String> arguments,
            required Map<String, String>? environment,
            required Duration timeout,
          }) async => LaunchEnvironmentProcessResult(exitCode: 0, path: shellPath, stderr: ""),
          shellTimeout: const Duration(seconds: 5),
        );

        expect(await environment.resolve(), isEmpty, reason: shellPath);
      }
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
              return const LaunchEnvironmentProcessResult(exitCode: 0, path: null, stderr: "");
            },
        shellTimeout: const Duration(seconds: 5),
      );

      final Map<String, String> resolved = await environment.resolve();

      expect(calls, 0);
      expect(resolved, isEmpty);
    });
  });
}
