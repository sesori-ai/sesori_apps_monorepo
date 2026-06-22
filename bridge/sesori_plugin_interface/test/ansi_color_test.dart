import "dart:io";

import "package:sesori_plugin_interface/src/ansi_color.dart";
import "package:test/test.dart";

void main() {
  group("AnsiColorFormatter", () {
    test("wraps text in the color code when the terminal supports ANSI", () {
      final result = AnsiColorFormatter.colorize(
        text: "hello",
        color: AnsiColor.red,
        out: _FakeStdout(supportsAnsiEscapes: true),
        environment: const {},
      );

      expect(result, equals("${AnsiColor.red.code}hello\x1B[0m"));
    });

    test("returns text unchanged when the terminal does not support ANSI", () {
      final result = AnsiColorFormatter.colorize(
        text: "hello",
        color: AnsiColor.yellow,
        out: _FakeStdout(supportsAnsiEscapes: false),
        environment: const {},
      );

      expect(result, equals("hello"));
    });

    test("returns text unchanged when the capability probe throws", () {
      final result = AnsiColorFormatter.colorize(
        text: "hello",
        color: AnsiColor.yellow,
        out: _ThrowingStdout(),
        environment: const {},
      );

      expect(result, equals("hello"));
    });

    test("returns text unchanged when NO_COLOR is set, even on a capable terminal", () {
      final result = AnsiColorFormatter.colorize(
        text: "hello",
        color: AnsiColor.red,
        out: _FakeStdout(supportsAnsiEscapes: true),
        environment: const {"NO_COLOR": "1"},
      );

      expect(result, equals("hello"), reason: "NO_COLOR must disable color regardless of terminal support");
    });

    test("honors NO_COLOR even when set to an empty value", () {
      final result = AnsiColorFormatter.colorize(
        text: "hello",
        color: AnsiColor.red,
        out: _FakeStdout(supportsAnsiEscapes: true),
        environment: const {"NO_COLOR": ""},
      );

      expect(result, equals("hello"), reason: "presence of NO_COLOR disables color regardless of its value");
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
