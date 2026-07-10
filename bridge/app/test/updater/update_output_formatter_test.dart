import 'dart:io';

import 'package:sesori_bridge/src/updater/formatters/update_output_formatter.dart';
import 'package:test/test.dart';

class _FakeStdout implements Stdout {
  _FakeStdout({required this.supportsAnsiEscapes});

  @override
  final bool supportsAnsiEscapes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('UpdateOutputFormatter', () {
    const plain = UpdateOutputFormatter(color: false, unicode: false);
    const colorUnicode = UpdateOutputFormatter(color: true, unicode: true);

    test('plain ASCII prefixes carry a glyph and no ANSI', () {
      expect(plain.success('done'), '[OK] done');
      expect(plain.warn('careful'), '! careful');
      expect(plain.error('nope'), 'x nope');
      expect(plain.note('fyi'), '> fyi');
      expect(plain.dim('quiet'), 'quiet');
      expect(plain.command('run me'), 'run me');
      expect(plain.arrow, '->');
      expect(plain.color, isFalse);
      for (final rendered in [plain.success('a'), plain.error('b'), plain.dim('c')]) {
        expect(rendered, isNot(contains('\x1B')));
      }
    });

    test('color + unicode uses glyphs and wraps text in ANSI', () {
      expect(colorUnicode.success('done'), contains('\u2713')); // ✓
      expect(colorUnicode.warn('c'), contains('\u26a0')); // ⚠
      expect(colorUnicode.error('c'), contains('\u2717')); // ✗
      expect(colorUnicode.note('c'), contains('\u279c')); // ➜
      expect(colorUnicode.arrow, '\u2192'); // →
      expect(colorUnicode.success('done'), contains('\x1B['));
      expect(colorUnicode.success('done'), contains('done'));
      expect(colorUnicode.color, isTrue);
    });

    test('color without unicode keeps ASCII glyphs but still adds ANSI', () {
      const formatter = UpdateOutputFormatter(color: true, unicode: false);
      final rendered = formatter.success('done');
      expect(rendered, contains('[OK]'));
      expect(rendered, contains('\x1B['));
      expect(rendered, isNot(contains('\u2713')));
    });

    group('progressBar', () {
      test('unicode + color renders ■ filled and ･ remainder with ANSI', () {
        final bar = colorUnicode.progressBar(filledCells: 4, totalCells: 10);
        expect(bar, contains('\u25a0' * 4)); // ■■■■
        expect(bar, contains('\uff65' * 6)); // ･･････
        expect(bar, contains('\x1B['));
      });

      test('ascii + no color renders #/. with no ANSI', () {
        final bar = plain.progressBar(filledCells: 3, totalCells: 8);
        expect(bar, '${'#' * 3}${'.' * 5}');
        expect(bar, isNot(contains('\x1B')));
      });

      test('clamps filled cells to the total width', () {
        expect(plain.progressBar(filledCells: 99, totalCells: 5), '#####');
      });
    });

    group('forStream', () {
      test('resolves color from the stream and unicode from the locale', () {
        final formatter = UpdateOutputFormatter.forStream(
          out: _FakeStdout(supportsAnsiEscapes: true),
          environment: const {'LANG': 'en_US.UTF-8'},
        );
        expect(formatter.color, isTrue);
        expect(formatter.success('x'), contains('\u2713'));
      });

      test('NO_COLOR disables color even on a capable stream', () {
        final formatter = UpdateOutputFormatter.forStream(
          out: _FakeStdout(supportsAnsiEscapes: true),
          environment: const {'NO_COLOR': '1', 'LANG': 'en_US.UTF-8'},
        );
        expect(formatter.color, isFalse);
        expect(formatter.success('x'), isNot(contains('\x1B')));
      });

      test('a non-ANSI stream falls back to plain ASCII', () {
        final formatter = UpdateOutputFormatter.forStream(
          out: _FakeStdout(supportsAnsiEscapes: false),
          environment: const <String, String>{},
        );
        expect(formatter.color, isFalse);
        expect(formatter.success('x'), '[OK] x');
      });
    });
  });
}
