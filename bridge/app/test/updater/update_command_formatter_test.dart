import 'dart:io';

import 'package:sesori_bridge/src/updater/formatters/update_command_formatter.dart';
import 'package:sesori_bridge/src/updater/formatters/update_output_formatter.dart';
import 'package:sesori_bridge/src/updater/foundation/release_track.dart';
import 'package:sesori_bridge/src/updater/models/explicit_update_outcome.dart';
import 'package:test/test.dart';

class _FakeStdout implements Stdout {
  _FakeStdout({required this.supportsAnsiEscapes});

  @override
  final bool supportsAnsiEscapes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UpdateOutputFormatter _outputFormatter({required bool color, required bool unicode}) =>
    UpdateOutputFormatter.forStream(
      out: _FakeStdout(supportsAnsiEscapes: color),
      environment: unicode ? const {'LANG': 'en_US.UTF-8'} : const <String, String>{},
    );

UpdateCommandFormatter _formatter({bool color = false, bool unicode = false}) {
  final output = _outputFormatter(color: color, unicode: unicode);
  return UpdateCommandFormatter(outFormatter: output, errFormatter: output);
}

void main() {
  group('UpdateCommandFormatter', () {
    test('renders a plain ASCII upgrade with no color', () {
      final lines = _formatter().format(
        outcome: const ExplicitUpdateApplied(
          fromVersion: '1.0.0',
          toVersion: '2.0.0',
          kind: UpdateAppliedKind.upgrade,
          track: ReleaseTrack.stable,
        ),
      );

      expect(lines, hasLength(2));
      expect(lines.first.isError, isFalse);
      expect(lines.first.text, '[OK] Updated v1.0.0 -> v2.0.0');
      expect(lines.first.text, isNot(contains('\x1B')));
      expect(lines[1].isError, isFalse);
      expect(lines[1].text, contains('Takes effect on next launch'));
    });

    test('uses unicode glyphs and ANSI when supported', () {
      final lines = _formatter(color: true, unicode: true).format(
        outcome: const ExplicitUpdateApplied(
          fromVersion: '1.0.0',
          toVersion: '2.0.0',
          kind: UpdateAppliedKind.upgrade,
          track: ReleaseTrack.stable,
        ),
      );

      expect(lines.first.text, contains('\u2713')); // ✓
      expect(lines.first.text, contains('\u2192')); // →
      expect(lines.first.text, contains('\x1B['));
    });

    test('reinstall and downgrade headlines read naturally', () {
      final reinstall = _formatter().format(
        outcome: const ExplicitUpdateApplied(
          fromVersion: '2.0.0',
          toVersion: '2.0.0',
          kind: UpdateAppliedKind.reinstall,
          track: ReleaseTrack.stable,
        ),
      );
      expect(reinstall.first.text, '[OK] Reinstalled v2.0.0 (stable).');

      final downgrade = _formatter().format(
        outcome: const ExplicitUpdateApplied(
          fromVersion: '2.0.0-internal.3',
          toVersion: '1.5.0',
          kind: UpdateAppliedKind.downgrade,
          track: ReleaseTrack.stable,
        ),
      );
      expect(downgrade.first.text, '[OK] Switched to stable v1.5.0.');
    });

    test('already-latest is a single stdout line', () {
      final lines = _formatter().format(
        outcome: const ExplicitUpdateAlreadyLatest(version: '2.0.0', track: ReleaseTrack.stable),
      );

      expect(lines, hasLength(1));
      expect(lines.first.isError, isFalse);
      expect(lines.first.text, "[OK] You're on the latest stable build (v2.0.0).");
    });

    test('track mismatch is informational on stdout with a force hint', () {
      final lines = _formatter().format(
        outcome: const ExplicitUpdateTrackMismatch(
          currentVersion: '2.0.0-internal.3',
          latestVersion: '1.5.0',
          track: ReleaseTrack.stable,
        ),
      );

      expect(lines.every((line) => !line.isError), isTrue);
      expect(lines.any((line) => line.text.contains('update --force')), isTrue);
      expect(lines.any((line) => line.text.contains('1.5.0')), isTrue);
    });

    test('failures and refusals go to stderr', () {
      expect(
        _formatter().format(outcome: const ExplicitUpdateNotManaged(executablePath: '/x')).first.isError,
        isTrue,
      );
      expect(
        _formatter().format(outcome: const ExplicitUpdateNpmDirect(message: 'use npx @sesori/bridge')).first.isError,
        isTrue,
      );
      expect(_formatter().format(outcome: const ExplicitUpdateLockBusy()).first.isError, isTrue);
      expect(
        _formatter().format(outcome: const ExplicitUpdateNoEligibleRelease(track: ReleaseTrack.stable)).first.isError,
        isTrue,
      );

      final failed = _formatter().format(
        outcome: const ExplicitUpdateFailed(reason: 'boom', logPath: '/tmp/log'),
      );
      expect(failed.every((line) => line.isError), isTrue);
      expect(failed.any((line) => line.text.contains('boom')), isTrue);
      expect(failed.any((line) => line.text.contains('/tmp/log')), isTrue);
    });

    test('NO_COLOR strips ANSI even on a capable terminal', () {
      final output = UpdateOutputFormatter.forStream(
        out: _FakeStdout(supportsAnsiEscapes: true),
        environment: const {'NO_COLOR': '1', 'LANG': 'en_US.UTF-8'},
      );
      final formatter = UpdateCommandFormatter(outFormatter: output, errFormatter: output);

      final lines = formatter.format(
        outcome: const ExplicitUpdateAlreadyLatest(version: '2.0.0', track: ReleaseTrack.stable),
      );

      expect(lines.first.text, isNot(contains('\x1B')));
      expect(lines.first.text, contains('\u2713')); // glyph still unicode; only color is gated off
    });
  });
}
