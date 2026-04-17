import "package:sesori_bridge/src/push/push_session_state_mutator.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker_state.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PushSessionStateMutator", () {
    group("upsertSession", () {
      test("creates new session", () {
        final sessions = <String, PushTrackedSessionState>{};
        final mutator = _createMutator(sessions: sessions);

        mutator.upsertSession(
          session: Session(
            id: "s1",
            projectID: "p1",
            directory: "/tmp",
            parentID: null,
            title: null,
            time: null,
            summary: null,
            pullRequest: null,
          ),
          touchedAt: DateTime.now(),
        );

        expect(sessions.containsKey("s1"), isTrue);
        expect(sessions["s1"]?.projectId, equals("p1"));
      });

      test("updates existing session", () {
        final sessions = <String, PushTrackedSessionState>{
          "s1": PushTrackedSessionState()..projectId = "old",
        };
        final mutator = _createMutator(sessions: sessions);

        mutator.upsertSession(
          session: Session(
            id: "s1",
            projectID: "new",
            directory: "/tmp",
            parentID: null,
            title: null,
            time: null,
            summary: null,
            pullRequest: null,
          ),
          touchedAt: DateTime.now(),
        );

        expect(sessions["s1"]?.projectId, equals("new"));
      });
    });

    group("deleteSession", () {
      test("removes session from map", () {
        final sessions = <String, PushTrackedSessionState>{
          "s1": PushTrackedSessionState(),
        };
        final mutator = _createMutator(sessions: sessions);

        mutator.deleteSession(sessionId: "s1");

        expect(sessions.containsKey("s1"), isFalse);
      });
    });

    group("trackMessageForSession / untrackMessage", () {
      test("tracks message for session", () {
        final sessions = <String, PushTrackedSessionState>{
          "s1": PushTrackedSessionState(),
        };
        final messageRoles = <String, PushTrackedMessageRole>{};
        final mutator = _createMutator(
          sessions: sessions,
          messageRoles: messageRoles,
        );

        mutator.trackMessageForSession(sessionId: "s1", messageId: "m1");

        expect(sessions["s1"]?.messageIds.contains("m1"), isTrue);
      });

      test("untracks message from session", () {
        final sessions = <String, PushTrackedSessionState>{
          "s1": PushTrackedSessionState()..messageIds.add("m1"),
        };
        final messageRoles = <String, PushTrackedMessageRole>{
          "m1": PushTrackedMessageRole(role: "user", sessionId: "s1", updatedAt: DateTime.now()),
        };
        final mutator = _createMutator(
          sessions: sessions,
          messageRoles: messageRoles,
        );

        mutator.untrackMessage(messageId: "m1");

        expect(sessions["s1"]?.messageIds.contains("m1"), isFalse);
        expect(messageRoles.containsKey("m1"), isFalse);
      });
    });
  });
}

PushSessionStateMutator _createMutator({
  Map<String, PushTrackedSessionState>? sessions,
  Map<String, PushTrackedMessageRole>? messageRoles,
}) {
  return PushSessionStateMutator(
    sessions: sessions ?? <String, PushTrackedSessionState>{},
    messageRoles: messageRoles ?? <String, PushTrackedMessageRole>{},
    permissionRequestToSession: <String, String>{},
  );
}
