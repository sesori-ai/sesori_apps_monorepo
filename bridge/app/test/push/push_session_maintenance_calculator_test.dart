import "package:sesori_bridge/src/push/push_session_maintenance_calculator.dart";
import "package:sesori_bridge/src/push/push_session_state_graph.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker_state.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PushSessionMaintenanceCalculator", () {
    group("findPrunableRoots", () {
      test("returns empty list when no sessions", () {
        final sessions = <String, PushTrackedSessionState>{};
        final calculator = _createCalculator(
          sessions: sessions,
          now: () => DateTime(2026, 4, 16, 12, 0),
        );

        expect(calculator.findPrunableRoots(), isEmpty);
      });

      test("active non-idle roots are not prunable", () {
        final sessions = <String, PushTrackedSessionState>{
          "root1": PushTrackedSessionState()
            ..status = SessionStatus.busy()
            ..lastTouchedAt = DateTime(2026, 4, 16, 11, 0),
        };
        final calculator = _createCalculator(
          sessions: sessions,
          now: () => DateTime(2026, 4, 16, 12, 0),
        );

        expect(calculator.findPrunableRoots(), isEmpty);
      });

      test("idle roots within TTL are not prunable", () {
        final sessions = <String, PushTrackedSessionState>{
          "root1": PushTrackedSessionState()
            ..status = null
            ..lastTouchedAt = DateTime(2026, 4, 16, 11, 45),
        };
        final calculator = _createCalculator(
          sessions: sessions,
          now: () => DateTime(2026, 4, 16, 12, 0),
        );

        expect(calculator.findPrunableRoots(), isEmpty);
      });

      test("idle roots past TTL are prunable", () {
        final sessions = <String, PushTrackedSessionState>{
          "root1": PushTrackedSessionState()
            ..status = null
            ..lastTouchedAt = DateTime(2026, 4, 16, 10, 0),
        };
        final calculator = _createCalculator(
          sessions: sessions,
          now: () => DateTime(2026, 4, 16, 12, 0),
        );

        final prunable = calculator.findPrunableRoots();
        expect(prunable.length, equals(1));
        expect(prunable.first.rootSessionId, equals("root1"));
      });
    });

    group("buildTelemetrySnapshot", () {
      test("correctly counts sessions", () {
        final sessions = <String, PushTrackedSessionState>{
          "s1": PushTrackedSessionState(),
          "s2": PushTrackedSessionState(),
        };
        final calculator = _createCalculator(sessions: sessions);

        final snapshot = calculator.buildTelemetrySnapshot();
        expect(snapshot.sessionCount, equals(2));
      });
    });
  });
}

PushSessionMaintenanceCalculator _createCalculator({
  Map<String, PushTrackedSessionState>? sessions,
  Map<String, PushTrackedMessageRole>? messageRoles,
  DateTime Function()? now,
}) {
  final resolvedSessions = sessions ?? <String, PushTrackedSessionState>{};
  final resolvedMessageRoles = messageRoles ?? <String, PushTrackedMessageRole>{};
  final resolvedNow = now ?? () => DateTime(2026, 4, 16, 12, 0);

  final graph = PushSessionStateGraph(sessions: resolvedSessions);

  return PushSessionMaintenanceCalculator(
    sessions: resolvedSessions,
    messageRoles: resolvedMessageRoles,
    permissionRequestCount: () => 0,
    graph: graph,
    now: resolvedNow,
  );
}
