import 'package:sesori_bridge/src/server/foundation/process_identity.dart';
import 'package:sesori_bridge/src/server/foundation/process_user.dart';
import 'package:test/test.dart';

void main() {
  group('ProcessIdentity.hasSameIdentityAs', () {
    test('returns true when both identities are identical', () {
      final identity = _identity(pid: 100, startMarker: 'marker-1');
      expect(identity.hasSameIdentityAs(identity), isTrue);
    });

    test('returns true when pid and startMarker match', () {
      final a = _identity(pid: 100, startMarker: 'marker-1');
      final b = _identity(pid: 100, startMarker: 'marker-1');
      expect(a.hasSameIdentityAs(b), isTrue);
    });

    test('returns false when pids differ', () {
      final a = _identity(pid: 100, startMarker: 'marker-1');
      final b = _identity(pid: 200, startMarker: 'marker-1');
      expect(a.hasSameIdentityAs(b), isFalse);
    });

    test('returns false when startMarkers differ', () {
      final a = _identity(pid: 100, startMarker: 'marker-1');
      final b = _identity(pid: 100, startMarker: 'marker-2');
      expect(a.hasSameIdentityAs(b), isFalse);
    });

    test('startMarker comparison short-circuits commandLine and executablePath', () {
      final a = _identity(
        pid: 100,
        startMarker: 'marker-1',
        commandLine: 'cmd-a',
        executablePath: '/path/a',
      );
      final b = _identity(
        pid: 100,
        startMarker: 'marker-1',
        commandLine: 'cmd-b',
        executablePath: '/path/b',
      );
      expect(a.hasSameIdentityAs(b), isTrue);
    });

    group('without start markers', () {
      test('returns true when commandLine and executablePath match', () {
        final a = _identity(pid: 100, startMarker: null, commandLine: 'cmd', executablePath: '/path');
        final b = _identity(pid: 100, startMarker: null, commandLine: 'cmd', executablePath: '/path');
        expect(a.hasSameIdentityAs(b), isTrue);
      });

      test('returns false when commandLine differs', () {
        final a = _identity(pid: 100, startMarker: null, commandLine: 'cmd-a', executablePath: '/path');
        final b = _identity(pid: 100, startMarker: null, commandLine: 'cmd-b', executablePath: '/path');
        expect(a.hasSameIdentityAs(b), isFalse);
      });

      test('returns false when executablePath differs', () {
        final a = _identity(pid: 100, startMarker: null, commandLine: 'cmd', executablePath: '/path/a');
        final b = _identity(pid: 100, startMarker: null, commandLine: 'cmd', executablePath: '/path/b');
        expect(a.hasSameIdentityAs(b), isFalse);
      });

      test('returns false when both commandLine and executablePath differ', () {
        final a = _identity(pid: 100, startMarker: null, commandLine: 'cmd-a', executablePath: '/path/a');
        final b = _identity(pid: 100, startMarker: null, commandLine: 'cmd-b', executablePath: '/path/b');
        expect(a.hasSameIdentityAs(b), isFalse);
      });
    });

    group('asymmetric startMarker presence', () {
      test('uses startMarker comparison when only self has marker', () {
        final a = _identity(pid: 100, startMarker: 'marker-1');
        final b = _identity(pid: 100, startMarker: null);
        expect(a.hasSameIdentityAs(b), isFalse);
      });

      test('uses startMarker comparison when only other has marker', () {
        final a = _identity(pid: 100, startMarker: null);
        final b = _identity(pid: 100, startMarker: 'marker-1');
        expect(a.hasSameIdentityAs(b), isFalse);
      });

      test('ignores commandLine/executablePath when only self has marker', () {
        final a = _identity(pid: 100, startMarker: 'marker-1', commandLine: 'cmd-a', executablePath: '/path/a');
        final b = _identity(pid: 100, startMarker: null, commandLine: 'cmd-a', executablePath: '/path/a');
        expect(a.hasSameIdentityAs(b), isFalse);
      });
    });

    group('null executablePath handling', () {
      test('returns true when both executablePaths are null and commandLines match', () {
        final a = _identity(pid: 100, startMarker: null, commandLine: 'cmd', executablePath: null);
        final b = _identity(pid: 100, startMarker: null, commandLine: 'cmd', executablePath: null);
        expect(a.hasSameIdentityAs(b), isTrue);
      });

      test('returns false when one executablePath is null and other is not', () {
        final a = _identity(pid: 100, startMarker: null, commandLine: 'cmd', executablePath: null);
        final b = _identity(pid: 100, startMarker: null, commandLine: 'cmd', executablePath: '/path');
        expect(a.hasSameIdentityAs(b), isFalse);
      });
    });
  });
}

ProcessIdentity _identity({
  required int pid,
  required String? startMarker,
  String commandLine = 'test-cmd',
  String? executablePath = '/test/path',
}) {
  return ProcessIdentity(
    pid: pid,
    startMarker: startMarker,
    executablePath: executablePath,
    commandLine: commandLine,
    ownerUser: ProcessUser.fromRawUser('testuser'),
    platform: 'macos',
    capturedAt: DateTime.utc(2026, 5, 15, 12),
  );
}
