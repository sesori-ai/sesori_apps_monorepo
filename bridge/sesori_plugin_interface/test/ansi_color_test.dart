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
      );

      expect(result, equals("${AnsiColor.red.code}hello\x1B[0m"));
    });

    test("returns text unchanged when the terminal does not support ANSI", () {
      final result = AnsiColorFormatter.colorize(
        text: "hello",
        color: AnsiColor.yellow,
        out: _FakeStdout(supportsAnsiEscapes: false),
      );

      expect(result, equals("hello"));
    });

    test("returns text unchanged when the capability probe throws", () {
      final result = AnsiColorFormatter.colorize(
        text: "hello",
        color: AnsiColor.yellow,
        out: _ThrowingStdout(),
      );

      expect(result, equals("hello"));
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
