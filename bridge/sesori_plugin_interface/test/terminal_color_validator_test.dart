import "dart:io";

import "package:sesori_plugin_interface/src/terminal_color_validator.dart";
import "package:test/test.dart";

void main() {
  group("TerminalColorValidator", () {
    test("supported on a capable terminal with no overriding env", () {
      expect(
        TerminalColorValidator.isSupported(
          out: _FakeStdout(supportsAnsiEscapes: true),
          environment: const {},
        ),
        isTrue,
      );
    });

    test("not supported on a non-terminal with no overriding env", () {
      expect(
        TerminalColorValidator.isSupported(
          out: _FakeStdout(supportsAnsiEscapes: false),
          environment: const {},
        ),
        isFalse,
      );
    });

    test("not supported when the capability probe throws", () {
      expect(
        TerminalColorValidator.isSupported(
          out: _ThrowingStdout(),
          environment: const {},
        ),
        isFalse,
      );
    });

    test("FORCE_COLOR forces support even on a non-terminal", () {
      expect(
        TerminalColorValidator.isSupported(
          out: _FakeStdout(supportsAnsiEscapes: false),
          environment: const {"FORCE_COLOR": "1"},
        ),
        isTrue,
        reason: "FORCE_COLOR is an explicit opt-in that overrides the stream probe",
      );
    });

    test("FORCE_COLOR forces support without probing the stream", () {
      expect(
        TerminalColorValidator.isSupported(
          out: _ThrowingStdout(),
          environment: const {"FORCE_COLOR": ""},
        ),
        isTrue,
        reason: "FORCE_COLOR (even empty) short-circuits before the capability probe",
      );
    });

    test("FORCE_COLOR takes precedence over NO_COLOR", () {
      expect(
        TerminalColorValidator.isSupported(
          out: _FakeStdout(supportsAnsiEscapes: false),
          environment: const {"FORCE_COLOR": "1", "NO_COLOR": "1"},
        ),
        isTrue,
        reason: "the installer precedence checks FORCE_COLOR before NO_COLOR",
      );
    });

    test("NO_COLOR disables support on a capable terminal", () {
      expect(
        TerminalColorValidator.isSupported(
          out: _FakeStdout(supportsAnsiEscapes: true),
          environment: const {"NO_COLOR": "1"},
        ),
        isFalse,
      );
    });

    test("NO_COLOR disables support even when set to an empty value", () {
      expect(
        TerminalColorValidator.isSupported(
          out: _FakeStdout(supportsAnsiEscapes: true),
          environment: const {"NO_COLOR": ""},
        ),
        isFalse,
        reason: "presence of NO_COLOR disables color regardless of its value",
      );
    });

    test("TERM=dumb disables support on a capable terminal", () {
      expect(
        TerminalColorValidator.isSupported(
          out: _FakeStdout(supportsAnsiEscapes: true),
          environment: const {"TERM": "dumb"},
        ),
        isFalse,
      );
    });

    test("a non-dumb TERM defers to the stream probe", () {
      expect(
        TerminalColorValidator.isSupported(
          out: _FakeStdout(supportsAnsiEscapes: true),
          environment: const {"TERM": "xterm-256color"},
        ),
        isTrue,
      );
    });
  });
}

/// Stdout whose ANSI support can be controlled.
class _FakeStdout implements Stdout {
  _FakeStdout({required bool supportsAnsiEscapes}) : _supportsAnsiEscapes = supportsAnsiEscapes;

  final bool _supportsAnsiEscapes;

  @override
  bool get supportsAnsiEscapes => _supportsAnsiEscapes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stdout whose capability probe throws, mimicking exotic platforms.
class _ThrowingStdout implements Stdout {
  @override
  bool get supportsAnsiEscapes => throw UnsupportedError("no terminal");

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
