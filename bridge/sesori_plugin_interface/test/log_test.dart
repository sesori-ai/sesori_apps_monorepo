import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("Log", () {
    late LogLevel originalLevel;

    setUp(() => originalLevel = Log.level);
    tearDown(() => Log.level = originalLevel);

    test("every level writes to stderr and never to stdout", () {
      Log.level = LogLevel.verbose;
      final out = <String>[];
      final err = <String>[];

      IOOverrides.runZoned(
        () {
          Log.v("v-msg");
          Log.d("d-msg");
          Log.i("i-msg");
          Log.w("w-msg");
          Log.e("e-msg");
        },
        stdout: () => _CapturingStdout(out),
        stderr: () => _CapturingStdout(err),
      );

      expect(out, isEmpty, reason: "diagnostic logs must never pollute stdout");
      expect(err, hasLength(5));
    });

    test("messages below Log.level are discarded", () {
      Log.level = LogLevel.warning;
      final err = <String>[];

      IOOverrides.runZoned(
        () {
          Log.v("verbose");
          Log.d("debug");
          Log.i("info");
          Log.w("warning");
          Log.e("error");
        },
        stdout: () => _CapturingStdout(<String>[]),
        stderr: () => _CapturingStdout(err),
      );

      expect(err, hasLength(2), reason: "only warning and error pass at the warning level");
    });

    test("debug level is prefixed with the resolved caller class", () {
      Log.level = LogLevel.debug;
      final err = <String>[];

      IOOverrides.runZoned(
        () => _LogCaller().emit(),
        stdout: () => _CapturingStdout(<String>[]),
        stderr: () => _CapturingStdout(err),
      );

      expect(err, hasLength(1));
      expect(
        err.single,
        startsWith("[_LogCaller]"),
        reason: "the caller-frame index must resolve to the calling class at debug verbosity",
      );
      expect(err.single, contains("from-caller"));
    });

    test("info level omits the caller class tag to keep output clean", () {
      Log.level = LogLevel.info;
      final err = <String>[];

      IOOverrides.runZoned(
        () => _LogCaller().emit(),
        stdout: () => _CapturingStdout(<String>[]),
        stderr: () => _CapturingStdout(err),
      );

      expect(err, hasLength(1));
      expect(
        err.single,
        isNot(contains("[_LogCaller]")),
        reason: "the [Class] tag is debug-only noise and must be hidden at info level",
      );
      expect(err.single, equals("from-caller"));
    });

    test("warning and error are not colorized when stderr is not a terminal", () {
      Log.level = LogLevel.verbose;
      final err = <String>[];

      IOOverrides.runZoned(
        () {
          Log.w("w-msg");
          Log.e("e-msg");
        },
        stdout: () => _CapturingStdout(<String>[]),
        stderr: () => _CapturingStdout(err),
      );

      expect(err, hasLength(2));
      expect(
        err.every((line) => !line.contains("\x1B[")),
        isTrue,
        reason: "ANSI escapes must not leak into redirected/non-terminal output",
      );
    });
  });
}

/// Helper whose class name should appear in the resolved log prefix.
class _LogCaller {
  void emit() => Log.i("from-caller");
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
