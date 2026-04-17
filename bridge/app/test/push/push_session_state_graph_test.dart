import "package:sesori_bridge/src/push/push_session_state_graph.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker_state.dart";
import "package:test/test.dart";

void main() {
  group("PushSessionStateGraph", () {
    group("collectSubtreeSessionIds", () {
      test("single node returns just itself", () {
        final sessions = <String, PushTrackedSessionState>{
          "s1": PushTrackedSessionState(),
        };
        final graph = PushSessionStateGraph(sessions: sessions);

        expect(graph.collectSubtreeSessionIds(rootSessionId: "s1"), equals(["s1"]));
      });

      test("parent with children returns all", () {
        final sessions = <String, PushTrackedSessionState>{
          "parent": PushTrackedSessionState()..childIds.addAll(["child1", "child2"]),
          "child1": PushTrackedSessionState()..parentId = "parent",
          "child2": PushTrackedSessionState()..parentId = "parent",
        };
        final graph = PushSessionStateGraph(sessions: sessions);

        final result = graph.collectSubtreeSessionIds(rootSessionId: "parent");
        expect(result.length, equals(3));
        expect(result, containsAll(["parent", "child1", "child2"]));
      });

      test("missing session returns empty", () {
        final sessions = <String, PushTrackedSessionState>{};
        final graph = PushSessionStateGraph(sessions: sessions);

        expect(graph.collectSubtreeSessionIds(rootSessionId: "missing"), isEmpty);
      });
    });

    group("resolveRootSessionId", () {
      test("root session returns itself", () {
        final sessions = <String, PushTrackedSessionState>{
          "root": PushTrackedSessionState(),
        };
        final graph = PushSessionStateGraph(sessions: sessions);

        expect(graph.resolveRootSessionId(sessionId: "root"), equals("root"));
      });

      test("child returns parent root", () {
        final sessions = <String, PushTrackedSessionState>{
          "root": PushTrackedSessionState()..childIds.add("child"),
          "child": PushTrackedSessionState()..parentId = "root",
        };
        final graph = PushSessionStateGraph(sessions: sessions);

        expect(graph.resolveRootSessionId(sessionId: "child"), equals("root"));
      });

      test("orphan returns itself", () {
        final sessions = <String, PushTrackedSessionState>{
          "orphan": PushTrackedSessionState()..parentId = "nonexistent",
        };
        final graph = PushSessionStateGraph(sessions: sessions);

        expect(graph.resolveRootSessionId(sessionId: "orphan"), equals("orphan"));
      });
    });
  });
}
