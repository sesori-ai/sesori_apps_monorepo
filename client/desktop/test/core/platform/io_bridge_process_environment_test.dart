import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/io_bridge_process_environment.dart";

void main() {
  group("IoBridgeProcessEnvironment", () {
    test("resolves and caches a login-shell PATH without dropping valid Unicode entries", () async {
      var calls = 0;
      String? shell;
      List<String>? capturedArguments;
      final String shellOutput = <String>[
        "BASH_FUNC_path%%=() {\nPATH=\$PATH:/injected\n}",
        "PATH=/shell/bin:/base/bin:/non-\u00e9:relative",
        "SECRET_FROM_SHELL=do-not-copy",
      ].join("\u0000");
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
              return ProcessResult(1, 0, shellOutput, "");
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
              return ProcessResult(
                1,
                0,
                "PATH=/custom/shell/bin",
                "",
              );
            },
        shellTimeout: const Duration(seconds: 5),
      );

      final Map<String, String> resolved = await environment.resolve();

      expect(invokedShell, configuredShell);
      expect(resolved["PATH"], "/custom/shell/bin:/base/bin");
    });

    test("preserves the inherited environment when the login shell cannot be resolved", () async {
      final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
        isMacOS: true,
        baseEnvironment: const <String, String>{"PATH": "/system/bin"},
        runProcess: ({
          required String executable,
          required List<String> arguments,
          required Map<String, String>? environment,
          required Duration timeout,
        }) async => ProcessResult(1, 1, "", "login shell unavailable"),
        shellTimeout: const Duration(seconds: 5),
      );

      final Map<String, String> resolved = await environment.resolve();

      expect(resolved, isEmpty);
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
              return ProcessResult(1, 0, "", "");
            },
        shellTimeout: const Duration(seconds: 5),
      );

      final Map<String, String> resolved = await environment.resolve();

      expect(calls, 0);
      expect(resolved, isEmpty);
    });
  });
}
