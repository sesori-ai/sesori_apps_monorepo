import "package:sesori_dart_core/src/services/models/new_session_backend_scope.dart";
import "package:test/test.dart";

void main() {
  group("NewSessionBackendScope", () {
    test("invalidating an identified scope preserves only its last bridge ID", () {
      const verified = NewSessionBackendScope.verified(bridgeId: "bridge-a");

      final invalidated = verified.invalidate();

      expect(invalidated, const NewSessionBackendScope.unverified(lastIdentifiedBridgeId: "bridge-a"));
      expect(invalidated.isVerified, isFalse);
      expect(invalidated.identifiedBridgeId, isNull);
    });

    test("same identified bridge retains backend-local state", () {
      final transition = const NewSessionBackendScope.unverified(
        lastIdentifiedBridgeId: "bridge-a",
      ).transitionToDiscovered(bridgeId: "bridge-a");

      expect(transition.retainsBackendState, isTrue);
      expect(transition.scope, const NewSessionBackendScope.verified(bridgeId: "bridge-a"));
    });

    test("different identified bridge invalidates backend-local state", () {
      final transition = const NewSessionBackendScope.unverified(
        lastIdentifiedBridgeId: "bridge-a",
      ).transitionToDiscovered(bridgeId: "bridge-b");

      expect(transition.retainsBackendState, isFalse);
      expect(transition.scope, const NewSessionBackendScope.verified(bridgeId: "bridge-b"));
    });

    test("unidentified discovery is usable but cannot retain prior backend state", () {
      final transition = const NewSessionBackendScope.unverified(
        lastIdentifiedBridgeId: null,
      ).transitionToDiscovered(bridgeId: null);

      expect(transition.retainsBackendState, isFalse);
      expect(transition.scope.isVerified, isTrue);
      expect(transition.scope.identifiedBridgeId, isNull);
    });
  });
}
