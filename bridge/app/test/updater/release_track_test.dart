import 'dart:io';

import 'package:sesori_bridge/src/updater/foundation/release_track.dart';
import 'package:test/test.dart';

void main() {
  group('ReleaseTrack', () {
    test('wireValue is the enum name', () {
      expect(ReleaseTrack.stable.wireValue, equals('stable'));
      expect(ReleaseTrack.internal.wireValue, equals('internal'));
    });

    group('fromWire', () {
      test('maps known values', () {
        expect(ReleaseTrack.fromWire('stable'), ReleaseTrack.stable);
        expect(ReleaseTrack.fromWire('internal'), ReleaseTrack.internal);
      });

      test('treats a missing value (null) as stable without logging', () {
        final stderrLines = <String>[];
        late final ReleaseTrack track;

        IOOverrides.runZoned(
          () => track = ReleaseTrack.fromWire(null),
          stderr: () => _CapturingStdout(stderrLines),
        );

        expect(track, ReleaseTrack.stable);
        expect(stderrLines, isEmpty, reason: 'the unconfigured case is expected, not a warning');
      });

      test('falls back to stable and logs to stderr for an unexpected value', () {
        final stderrLines = <String>[];
        final stdoutLines = <String>[];
        late final ReleaseTrack track;

        IOOverrides.runZoned(
          () => track = ReleaseTrack.fromWire('nightly'),
          stderr: () => _CapturingStdout(stderrLines),
          stdout: () => _CapturingStdout(stdoutLines),
        );

        expect(track, ReleaseTrack.stable);
        expect(stderrLines, hasLength(1));
        expect(stderrLines.single, contains("Unknown release track 'nightly'"));
        expect(stdoutLines, isEmpty, reason: 'stdout must stay machine-clean for --version/--help');
      });
    });
  });
}

/// Captures `writeln` calls; [IOOverrides] swaps it in for stdout/stderr.
class _CapturingStdout implements Stdout {
  _CapturingStdout(this.lines);

  final List<String> lines;

  @override
  void writeln([Object? object = '']) {
    lines.add(object.toString());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
