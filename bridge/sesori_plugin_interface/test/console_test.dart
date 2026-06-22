import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("Console", () {
    test("message writes to stdout and never to stderr", () {
      final out = <String>[];
      final err = <String>[];

      IOOverrides.runZoned(
        () => Console.message(text: "hello, user"),
        stdout: () => _CapturingStdout(out),
        stderr: () => _CapturingStdout(err),
      );

      expect(out, equals(["hello, user"]));
      expect(err, isEmpty);
    });

    test("warning writes to stderr and never to stdout", () {
      final out = <String>[];
      final err = <String>[];

      IOOverrides.runZoned(
        () => Console.warning(text: "heads up"),
        stdout: () => _CapturingStdout(out),
        stderr: () => _CapturingStdout(err),
      );

      expect(err, equals(["heads up"]));
      expect(out, isEmpty);
    });

    test("error writes to stderr and never to stdout", () {
      final out = <String>[];
      final err = <String>[];

      IOOverrides.runZoned(
        () => Console.error(text: "something went wrong"),
        stdout: () => _CapturingStdout(out),
        stderr: () => _CapturingStdout(err),
      );

      expect(err, equals(["something went wrong"]));
      expect(out, isEmpty);
    });

    test("warning and error are not colorized for non-terminal stderr", () {
      final err = <String>[];

      IOOverrides.runZoned(
        () {
          Console.warning(text: "warn");
          Console.error(text: "boom");
        },
        stdout: () => _CapturingStdout(<String>[]),
        stderr: () => _CapturingStdout(err),
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
        () => Console.message(text: "must still be visible"),
        stdout: () => _CapturingStdout(out),
        stderr: () => _CapturingStdout(<String>[]),
      );

      expect(out, equals(["must still be visible"]));
    });
  });
}

/// Captures [writeln] calls; [IOOverrides] swaps it in for stdout/stderr.
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
