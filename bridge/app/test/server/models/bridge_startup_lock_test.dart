import 'package:sesori_bridge/src/server/models/bridge_startup_lock.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeStartupLock', () {
    test('matchesStartMarkerOf returns true for equal non-null markers', () {
      const lock = BridgeStartupLock(bridgePid: 123, bridgeStartMarker: 'marker');

      expect(lock.matchesStartMarkerOf(identity: _identity(startMarker: 'marker')), isTrue);
    });

    test('matchesStartMarkerOf returns false for mismatched non-null markers', () {
      const lock = BridgeStartupLock(bridgePid: 123, bridgeStartMarker: 'marker');

      expect(lock.matchesStartMarkerOf(identity: _identity(startMarker: 'other')), isFalse);
    });

    test('matchesStartMarkerOf returns false for one-sided null markers', () {
      const lock = BridgeStartupLock(bridgePid: 123, bridgeStartMarker: 'marker');
      const nullMarkerLock = BridgeStartupLock(bridgePid: 123, bridgeStartMarker: null);

      expect(lock.matchesStartMarkerOf(identity: _identity(startMarker: null)), isFalse);
      // A null lock marker against a real (e.g. POSIX) inspected marker is read
      // as a mismatch — i.e. the holder looks stale and the lock would be
      // stolen. This is exactly why a POSIX self-inspection failure must NOT
      // degrade to a marker-less fallback identity (which would write
      // bridgeStartMarker: null into the lock); on POSIX such failures stay
      // fatal instead. See BridgeRuntimeRunner._resolveCurrentBridgeIdentity.
      expect(nullMarkerLock.matchesStartMarkerOf(identity: _identity(startMarker: 'marker')), isFalse);
    });

    test('matchesStartMarkerOf returns true when both markers are null', () {
      const lock = BridgeStartupLock(bridgePid: 123, bridgeStartMarker: null);

      expect(lock.matchesStartMarkerOf(identity: _identity(startMarker: null)), isTrue);
    });
  });
}

ProcessIdentity _identity({required String? startMarker}) {
  return ProcessIdentity(
    pid: 123,
    startMarker: startMarker,
    executablePath: '/usr/local/bin/sesori-bridge',
    commandLine: 'sesori-bridge',
    ownerUser: ProcessUser.fromRawUser('alex'),
    platform: 'macos',
    capturedAt: DateTime.utc(2026, 5, 15),
  );
}
