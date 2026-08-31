import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/io_bridge_process_environment.dart";

void main() {
  group("IoBridgeProcessEnvironment", () {
    test("resolves only the login-shell PATH and caches the result", () async {
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
              return ProcessResult(
                1,
                0,
                "shell startup output\nSECRET_FROM_SHELL=do-not-copy\n"
                    "__SESORI_PATH_BEGIN__/shell/bin:/base/bin:/non-\u00e9:relative__SESORI_PATH_END__\n",
                "",
              );
            },
        shellTimeout: const Duration(seconds: 5),
        fallbackPathDirectories: const <String>["/fallback/bin", "/base/bin"],
      );

      final Map<String, String> first = await environment.resolve();
      final Map<String, String> second = await environment.resolve();

      expect(first, same(second));
      expect(calls, 1);
      expect(shell, "/bin/zsh");
      expect(capturedArguments, [
        "-ilc",
        r'printf "__SESORI_PATH_BEGIN__%s__SESORI_PATH_END__\n" "$PATH"',
      ]);
      expect(first["PATH"], "/shell/bin:/base/bin:/fallback/bin");
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
                "__SESORI_PATH_BEGIN__/custom/shell/bin__SESORI_PATH_END__",
                "",
              );
            },
        shellTimeout: const Duration(seconds: 5),
        fallbackPathDirectories: const <String>["/fallback/bin"],
      );

      final Map<String, String> resolved = await environment.resolve();

      expect(invokedShell, configuredShell);
      expect(resolved["PATH"], "/custom/shell/bin:/base/bin:/fallback/bin");
    });

    test("uses fallback paths when the login shell cannot be resolved", () async {
      final IoBridgeProcessEnvironment environment = IoBridgeProcessEnvironment.forTesting(
        isMacOS: true,
        baseEnvironment: const <String, String>{"PATH": "/system/bin"},
        runProcess: ({
          required String executable,
          required List<String> arguments,
          required Map<String, String>? environment,
          required Duration timeout,
        }) async => throw const ProcessException("/bin/zsh", <String>[], "unavailable", 1),
        shellTimeout: const Duration(seconds: 5),
        fallbackPathDirectories: const <String>["/user/bin"],
      );

      final Map<String, String> resolved = await environment.resolve();

      expect(resolved["PATH"], "/system/bin:/user/bin");
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
        fallbackPathDirectories: const <String>["/unused"],
      );

      final Map<String, String> resolved = await environment.resolve();

      expect(calls, 0);
      expect(resolved, isEmpty);
    });
  });
}
