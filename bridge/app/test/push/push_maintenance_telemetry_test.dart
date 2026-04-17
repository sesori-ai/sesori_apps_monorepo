import "package:sesori_bridge/src/push/completion_notifier.dart";
import "package:sesori_bridge/src/push/push_maintenance_telemetry.dart";
import "package:sesori_bridge/src/push/push_rate_limiter.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker_types.dart";
import "package:test/test.dart";

void main() {
  group("PushMaintenanceTelemetryBuilder", () {
    test("builds snapshot from tracker and dependency counts", () {
      final completionNotifier = FakeCompletionNotifier(
        permissionRequestCountValue: 2,
        completionSentRootCountValue: 3,
        abortedRootCountValue: 4,
      );
      final rateLimiter = FakePushRateLimiter(retainedKeyCountValue: 5);
      final builder = PushMaintenanceTelemetryBuilder(
        completionNotifier: completionNotifier,
        rateLimiter: rateLimiter,
        rssBytesReader: () => 8 * 1024 * 1024,
      );

      final snapshot = builder.build(
        trackerSnapshot: PushSessionTelemetrySnapshot(
          sessionCount: 7,
          rootSessionCount: 2,
          idleRootCount: 1,
          busySessionCount: 3,
          pendingQuestionCount: 1,
          pendingPermissionCount: 1,
          permissionRequestCount: 6,
          previouslyBusyCount: 2,
          latestAssistantTextCount: 4,
          latestAssistantTextCharCount: 123,
          messageRoleCount: 9,
          assistantMessageRoleCount: 5,
          oldestSessionActivityAt: null,
          oldestMessageRoleUpdatedAt: null,
          prunableRoots: [
            PushPrunableRoot(
              rootSessionId: "root",
              idleSince: DateTime(2026, 4, 16),
              retainedSessionCount: 3,
            ),
          ],
        ),
      );

      expect(snapshot.rssMb, closeTo(8, 0.001));
      expect(snapshot.sessions, equals(7));
      expect(snapshot.idleRoots, equals(1));
      expect(snapshot.prunableRoots, equals(1));
      expect(snapshot.messageRoles, equals(9));
      expect(snapshot.assistantTextSessions, equals(4));
      expect(snapshot.assistantTextChars, equals(123));
      expect(snapshot.trackerPermissionRequests, equals(6));
      expect(snapshot.notifierPermissionRequests, equals(2));
      expect(snapshot.completionSentRoots, equals(3));
      expect(snapshot.abortedRoots, equals(4));
      expect(snapshot.rateLimiterKeys, equals(5));
    });

    test("toLogMessage formats numeric fields consistently", () {
      const snapshot = PushMaintenanceTelemetrySnapshot(
        rssMb: 5.5,
        sessions: 1,
        idleRoots: 2,
        prunableRoots: 3,
        messageRoles: 4,
        assistantTextSessions: 5,
        assistantTextChars: 6,
        trackerPermissionRequests: 7,
        notifierPermissionRequests: 8,
        completionSentRoots: 9,
        abortedRoots: 10,
        rateLimiterKeys: 11,
      );

      expect(snapshot.toLogMessage(), contains("rss_mb=5.50"));
      expect(snapshot.toLogMessage(), contains("sessions=1"));
      expect(snapshot.toLogMessage(), contains("rate_limiter_keys=11"));
    });
  });
}

class FakeCompletionNotifier extends CompletionNotifier {
  final int permissionRequestCountValue;
  final int completionSentRootCountValue;
  final int abortedRootCountValue;

  FakeCompletionNotifier({
    required this.permissionRequestCountValue,
    required this.completionSentRootCountValue,
    required this.abortedRootCountValue,
  }) : super(tracker: PushSessionStateTracker(now: DateTime.now));

  @override
  int get permissionRequestCount => permissionRequestCountValue;

  @override
  int get completionSentRootCount => completionSentRootCountValue;

  @override
  int get abortedRootCount => abortedRootCountValue;
}

class FakePushRateLimiter extends PushRateLimiter {
  final int retainedKeyCountValue;

  FakePushRateLimiter({required this.retainedKeyCountValue}) : super(now: DateTime.now);

  @override
  int get retainedKeyCount => retainedKeyCountValue;
}
