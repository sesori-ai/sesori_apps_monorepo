import "package:sesori_dart_core/src/services/fast_mode_toggle_calculator.dart";
import "package:sesori_dart_core/src/testing/test_helpers.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _calculator = FastModeToggleCalculator();
const _available = FastModeSupport.available(promptCacheTtlSeconds: 1800);
final _now = DateTime.utc(2026, 9, 24, 12);

FastModeToggleDecision _decide({
  required FastModeSupport? support,
  required bool fastMode,
  required bool hasHistory,
  required DateTime? lastModelActivity,
}) => _calculator.decide(
  support: support,
  fastMode: fastMode,
  hasHistory: hasHistory,
  lastModelActivity: lastModelActivity,
  now: _now,
);

void main() {
  group("FastModeToggleCalculator control", () {
    test("is hidden when the model has no fast mode this build knows", () {
      expect(_calculator.control(support: null, fastMode: false), FastModeControl.hidden);
      expect(_calculator.control(support: const FastModeSupport.unknown(), fastMode: true), FastModeControl.hidden);
    });

    test("is disabled when the account cannot use fast mode", () {
      expect(
        _calculator.control(
          support: const FastModeSupport.unavailable(reason: FastModeUnavailableReason.extraUsageDisabled),
          fastMode: false,
        ),
        FastModeControl.unavailable,
      );
    });

    test("follows the choice when fast mode is available", () {
      expect(_calculator.control(support: _available, fastMode: true), FastModeControl.on);
      expect(_calculator.control(support: _available, fastMode: false), FastModeControl.off);
    });
  });

  group("FastModeToggleCalculator decide", () {
    test("reports why fast mode is unavailable", () {
      final decision = _decide(
        support: const FastModeSupport.unavailable(reason: FastModeUnavailableReason.disabledByOrganization),
        fastMode: false,
        hasHistory: true,
        lastModelActivity: _now,
      );

      expect(
        decision,
        isA<FastModeToggleUnavailable>().having(
          (decision) => decision.reason,
          "reason",
          FastModeUnavailableReason.disabledByOrganization,
        ),
      );
    });

    test("applies directly on a session without history", () {
      final decision = _decide(support: _available, fastMode: false, hasHistory: false, lastModelActivity: _now);

      expect(decision, isA<FastModeToggleApply>().having((decision) => decision.fastMode, "fastMode", isTrue));
    });

    test("confirms enabling and disabling while the cache is warm", () {
      final warm = _now.subtract(const Duration(minutes: 5));

      expect(
        _decide(support: _available, fastMode: false, hasHistory: true, lastModelActivity: warm),
        isA<FastModeToggleConfirmCacheReset>().having((decision) => decision.fastMode, "fastMode", isTrue),
      );
      expect(
        _decide(support: _available, fastMode: true, hasHistory: true, lastModelActivity: warm),
        isA<FastModeToggleConfirmCacheReset>().having((decision) => decision.fastMode, "fastMode", isFalse),
      );
    });

    test("the cache is warm until exactly its lifetime has passed", () {
      final justInside = _now.subtract(const Duration(seconds: 1799));
      final atLifetime = _now.subtract(const Duration(seconds: 1800));

      expect(
        _decide(support: _available, fastMode: false, hasHistory: true, lastModelActivity: justInside),
        isA<FastModeToggleConfirmCacheReset>(),
      );
      expect(
        _decide(support: _available, fastMode: false, hasHistory: true, lastModelActivity: atLifetime),
        isA<FastModeToggleApply>(),
      );
    });

    test("applies directly when the model's last activity is unknown", () {
      expect(
        _decide(support: _available, fastMode: true, hasHistory: true, lastModelActivity: null),
        isA<FastModeToggleApply>().having((decision) => decision.fastMode, "fastMode", isFalse),
      );
    });
  });

  group("FastModeToggleCalculator lastModelActivity", () {
    MessageWithParts assistant({required MessageSender sender, required int completed}) => MessageWithParts(
      info: Message.assistant(
        id: "msg-$completed",
        sessionID: "session-1",
        agent: null,
        modelID: null,
        providerID: null,
        sender: sender,
        time: MessageTime(created: completed - 1000, completed: completed),
      ),
      parts: const [],
    );

    test("ignores session automation envelopes", () {
      final activity = _calculator.lastModelActivity(
        messages: [
          assistant(sender: MessageSender.agent, completed: 1700000100000),
          assistant(sender: MessageSender.system, completed: 1700000900000),
        ],
        session: testSession(updatedAt: 1700000950000),
      );

      expect(activity, DateTime.fromMillisecondsSinceEpoch(1700000100000));
    });

    test("falls back to the session update without agent activity", () {
      final activity = _calculator.lastModelActivity(
        messages: [assistant(sender: MessageSender.system, completed: 1700000900000)],
        session: testSession(updatedAt: 1700000950000),
      );

      expect(activity, DateTime.fromMillisecondsSinceEpoch(1700000950000));
    });
  });
}
