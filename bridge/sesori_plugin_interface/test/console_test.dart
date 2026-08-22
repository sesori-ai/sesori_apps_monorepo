import "dart:io";

import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("Console", () {
    test("message writes to stdout and never to stderr", () {
      final out = <String>[];
      final err = <String>[];

      IOOverrides.runZoned(
        () => Console.message("hello, user"),
        stdout: () => CapturingStdout(lines: out),
        stderr: () => CapturingStdout(lines: err),
      );

      expect(out, equals(["hello, user"]));
      expect(err, isEmpty);
    });

    test("warning writes to stderr and never to stdout", () {
      final out = <String>[];
      final err = <String>[];

      IOOverrides.runZoned(
        () => Console.warning("heads up"),
        stdout: () => CapturingStdout(lines: out),
        stderr: () => CapturingStdout(lines: err),
      );

      expect(err, equals(["heads up"]));
      expect(out, isEmpty);
    });

    test("error writes to stderr and never to stdout", () {
      final out = <String>[];
      final err = <String>[];

      IOOverrides.runZoned(
        () => Console.error("something went wrong"),
        stdout: () => CapturingStdout(lines: out),
        stderr: () => CapturingStdout(lines: err),
      );

      expect(err, equals(["something went wrong"]));
      expect(out, isEmpty);
    });

    test("warning and error are not colorized for non-terminal stderr", () {
      final err = <String>[];

      IOOverrides.runZoned(
        () {
          Console.warning("warn");
          Console.error("boom");
        },
        stdout: () => CapturingStdout(lines: <String>[]),
        stderr: () => CapturingStdout(lines: err),
      );

      expect(
        err.every((line) => !line.contains("\x1B[")),
        isTrue,
        reason: "ANSI escapes must not leak into redirected/non-terminal output",
      );
    });

    test("message output is never gated by Log.level", () {
      final originalLevel = Log.level;
      addTearDown(() => Log.level = originalLevel);
      // Silence diagnostics entirely; user-facing output must still appear.
      Log.level = LogLevel.error;

      final out = <String>[];

      IOOverrides.runZoned(
        () => Console.message("must still be visible"),
        stdout: () => CapturingStdout(lines: out),
        stderr: () => CapturingStdout(lines: <String>[]),
      );

      expect(out, equals(["must still be visible"]));
    });
  });
}

/// Captures [writeln] calls; [IOOverrides] swaps it in for stdout/stderr.
