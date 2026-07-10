import 'package:sesori_bridge/src/updater/formatters/update_message_formatter.dart';
import 'package:sesori_bridge/src/updater/formatters/update_output_formatter.dart';
import 'package:test/test.dart';

UpdateMessageFormatter _formatter({bool color = false, bool unicode = false}) {
  final output = UpdateOutputFormatter(color: color, unicode: unicode);
  return UpdateMessageFormatter(outFormatter: output, errFormatter: output);
}

void main() {
  group('UpdateMessageFormatter', () {
    test('installedPendingActivation is a stdout success line + dim detail', () {
      final lines = _formatter().installedPendingActivation(toVersion: '2.0.0');

      expect(lines, hasLength(2));
      expect(lines.every((line) => !line.isError), isTrue);
      expect(lines.first.text, '[OK] Update v2.0.0 installed.');
      expect(lines[1].text, contains('next launch'));
      expect(lines[1].text, isNot(contains('\x1B')));
    });

    test('activated is a single stdout success line', () {
      final lines = _formatter().activated(toVersion: '2.0.0');

      expect(lines, hasLength(1));
      expect(lines.single.isError, isFalse);
      expect(lines.single.text, '[OK] Updated to v2.0.0.');
    });

    test('failureGuidance goes to stderr with reason, install URL, and log path', () {
      final lines = _formatter().failureGuidance(
        toVersion: '2.0.0',
        reason: 'disk full',
        logPath: '/tmp/update.log',
      );

      expect(lines, hasLength(3));
      expect(lines.every((line) => line.isError), isTrue);
      expect(lines[0].text, 'x Automatic update to 2.0.0 failed: disk full.');
      expect(lines[1].text, contains('https://sesori.com/'));
      expect(lines[2].text, contains('/tmp/update.log'));
    });

    test('failureGuidance keeps a phrase toVersion un-prefixed', () {
      final lines = _formatter().failureGuidance(
        toVersion: 'the latest release',
        reason: 'boom',
        logPath: '/tmp/update.log',
      );

      expect(lines.first.text, contains('update to the latest release failed'));
    });

    test('color + unicode adds ANSI and a glyph', () {
      final lines = _formatter(color: true, unicode: true).activated(toVersion: '2.0.0');

      expect(lines.single.text, contains('\u2713')); // ✓
      expect(lines.single.text, contains('\x1B['));
    });
  });
}
