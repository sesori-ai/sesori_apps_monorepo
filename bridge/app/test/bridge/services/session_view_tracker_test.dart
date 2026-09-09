import "package:sesori_bridge/src/services/session_view_tracker.dart";
import "package:test/test.dart";

void main() {
  group("SessionViewTracker", () {
    late SessionViewTracker tracker;

    setUp(() => tracker = SessionViewTracker());
    tearDown(() => tracker.dispose());

    test("isViewed reflects a single viewer", () {
      expect(tracker.isViewed(sessionId: "s1"), isFalse);
      tracker.setViewing(connID: 1, sessionId: "s1");
      expect(tracker.isViewed(sessionId: "s1"), isTrue);
    });

    test("emits viewStarts when a connection starts viewing", () {
      expectLater(tracker.viewStarts, emitsInOrder(["s1", "s2"]));
      tracker.setViewing(connID: 1, sessionId: "s1");
      tracker.setViewing(connID: 1, sessionId: "s2");
    });

    test("switching session updates both counts", () {
      tracker.setViewing(connID: 1, sessionId: "s1");
      tracker.setViewing(connID: 1, sessionId: "s2");
      expect(tracker.isViewed(sessionId: "s1"), isFalse);
      expect(tracker.isViewed(sessionId: "s2"), isTrue);
    });

    test("stays viewed while any connection still views it (global)", () {
      tracker.setViewing(connID: 1, sessionId: "s1");
      tracker.setViewing(connID: 2, sessionId: "s1");
      tracker.releaseConnection(connID: 1);
      expect(tracker.isViewed(sessionId: "s1"), isTrue);
      tracker.releaseConnection(connID: 2);
      expect(tracker.isViewed(sessionId: "s1"), isFalse);
    });

    test("setViewing(null) clears the connection's view", () {
      tracker.setViewing(connID: 1, sessionId: "s1");
      tracker.setViewing(connID: 1, sessionId: null);
      expect(tracker.isViewed(sessionId: "s1"), isFalse);
    });

    test("activeSessionIds contains each viewed session once and clears with viewers", () {
      tracker.setViewing(connID: 1, sessionId: "s1");
      tracker.setViewing(connID: 2, sessionId: "s1");
      tracker.setViewing(connID: 3, sessionId: "s2");

      expect(tracker.activeSessionIds, {"s1", "s2"});

      tracker.releaseConnection(connID: 1);
      expect(tracker.activeSessionIds, {"s1", "s2"});
      tracker.releaseConnection(connID: 2);
      expect(tracker.activeSessionIds, {"s2"});

      tracker.clearAll();
      expect(tracker.activeSessionIds, isEmpty);
    });
  });
}
