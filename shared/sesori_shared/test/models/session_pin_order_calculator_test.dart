import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const calculator = SessionPinOrderCalculator();
  // Listed a, b, c, d.
  const pinned = <PinnedSessionOrder>[
    (sessionId: "a", pinOrder: 40),
    (sessionId: "b", pinOrder: 30),
    (sessionId: "c", pinOrder: 20),
    (sessionId: "d", pinOrder: 10),
  ];

  List<String> listed(List<PinnedSessionOrder> rewrites) {
    final orders = {for (final row in pinned) row.sessionId: row.pinOrder};
    for (final row in rewrites) {
      orders[row.sessionId] = row.pinOrder;
    }
    return orders.keys.toList()..sort((x, y) => (orders[y] ?? 0).compareTo(orders[x] ?? 0));
  }

  List<PinnedSessionOrder> moved({required String sessionId, required String? afterSessionId}) {
    final rewrites = calculator.move(pinned: pinned, sessionId: sessionId, afterSessionId: afterSessionId);
    if (rewrites == null) fail("$sessionId was not found");
    return rewrites;
  }

  test("moving to the top rewrites only the moved session, above the rest", () {
    final rewrites = moved(sessionId: "c", afterSessionId: null);

    expect(rewrites, [(sessionId: "c", pinOrder: 41)]);
    expect(listed(rewrites), ["c", "a", "b", "d"]);
  });

  test("moving up rewrites the new order down to the moved session, top first", () {
    final rewrites = moved(sessionId: "d", afterSessionId: "a");

    expect(rewrites, [(sessionId: "a", pinOrder: 42), (sessionId: "d", pinOrder: 41)]);
    expect(listed(rewrites), ["a", "d", "b", "c"]);
  });

  test("moving down rewrites the rows it passes and leaves those below", () {
    final rewrites = moved(sessionId: "a", afterSessionId: "c");

    expect(rewrites, [(sessionId: "b", pinOrder: 43), (sessionId: "c", pinOrder: 42), (sessionId: "a", pinOrder: 41)]);
    expect(listed(rewrites), ["b", "c", "a", "d"]);
  });

  test("moving to the bottom puts the session last", () {
    expect(listed(moved(sessionId: "b", afterSessionId: "d")), ["a", "c", "d", "b"]);
  });

  test("applied top first, each prefix of the rewrites moves only the moved session", () {
    final rewrites = moved(sessionId: "a", afterSessionId: "c");

    // A list receiving b, then c, then a sees a step down the group at a time.
    expect(listed(rewrites.take(1).toList()), ["b", "a", "c", "d"]);
    expect(listed(rewrites.take(2).toList()), ["b", "c", "a", "d"]);
  });

  test("a session already in place rewrites nothing", () {
    expect(calculator.move(pinned: pinned, sessionId: "a", afterSessionId: null), isEmpty);
    expect(calculator.move(pinned: pinned, sessionId: "c", afterSessionId: "b"), isEmpty);
  });

  test("a session or anchor outside the group, or the session as its own anchor, is not found", () {
    expect(calculator.move(pinned: pinned, sessionId: "x", afterSessionId: null), isNull);
    expect(calculator.move(pinned: pinned, sessionId: "a", afterSessionId: "x"), isNull);
    expect(calculator.move(pinned: pinned, sessionId: "a", afterSessionId: "a"), isNull);
  });
}
