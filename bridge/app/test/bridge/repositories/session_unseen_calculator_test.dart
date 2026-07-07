import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:test/test.dart";

void main() {
  const calc = SessionUnseenCalculator();

  group("SessionUnseenCalculator", () {
    test("all-null baseline is seen", () {
      expect(calc.isUnseen(activity: null, userMessage: null, seen: null), isFalse);
    });

    test("activity newer than seen is unseen", () {
      expect(calc.isUnseen(activity: 200, userMessage: null, seen: 100), isTrue);
    });

    test("activity equal to seen is seen (strict greater-than)", () {
      expect(calc.isUnseen(activity: 100, userMessage: null, seen: 100), isFalse);
    });

    test("user's own latest message does not bold (userMessage == activity)", () {
      expect(calc.isUnseen(activity: 300, userMessage: 300, seen: 100), isFalse);
    });

    test("AI activity after the user's last message bolds", () {
      expect(calc.isUnseen(activity: 400, userMessage: 300, seen: 100), isTrue);
    });

    test("seen newer than activity (just viewed) is seen", () {
      expect(calc.isUnseen(activity: 300, userMessage: 100, seen: 500), isFalse);
    });

    test("mark-unread (seen=null) bolds iff activity newer than user message", () {
      expect(calc.isUnseen(activity: 400, userMessage: 300, seen: null), isTrue);
      expect(calc.isUnseen(activity: 300, userMessage: 300, seen: null), isFalse);
    });
  });
}
