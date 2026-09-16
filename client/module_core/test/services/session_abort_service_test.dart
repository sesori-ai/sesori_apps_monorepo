import "dart:async";

import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/services/session_abort_service.dart";
import "package:sesori_dart_core/src/testing/test_helpers.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _FakeRepository() extends SessionRepository {
  this : super(api: MockSessionApi());

  final abortedIds = <String>[];
  final abortResponses = <String, Future<ApiResponse<bool>> Function()>{};
  final children = <String, List<Session>>{};
  final childrenReads = <String>[];
  final statusResponses = <SessionStatusResponse>[];

  @override
  Future<ApiResponse<bool>> abortSession({
    required String sessionId,
    required SessionAbortSubAgentPolicy subAgents,
  }) {
    abortedIds.add(sessionId);
    return abortResponses[sessionId]?.call() ?? Future.value(ApiResponse.success(false));
  }

  @override
  Future<ApiResponse<SessionListResponse>> getChildren({required String sessionId}) async {
    childrenReads.add(sessionId);
    return ApiResponse.success(SessionListResponse(items: children[sessionId] ?? const []));
  }

  @override
  Future<ApiResponse<SessionStatusResponse>> getSessionStatuses() async =>
      ApiResponse.success(statusResponses.removeAt(0));
}

Future<void> _abort(_FakeRepository repository) =>
    SessionAbortService(repository: repository)
        .abortSession(sessionId: "root", subAgents: SessionAbortSubAgentPolicy.stop);

void main() {
  test("fresh traversal settles sibling, preserves failure details, and prunes handled branches", () async {
    final repository = _FakeRepository();
    final rootAbort = Completer<ApiResponse<bool>>();
    final descendantFailure = StateError("child 409");
    final descendantStack = StackTrace.fromString("descendant stack");
    repository.abortResponses.addAll({
      "root": () => rootAbort.future,
      "child": () => Future.error(descendantFailure, descendantStack),
      "grandchild": () async => ApiResponse.success(true),
      "sibling": () async => ApiResponse.success(true),
    });
    repository.statusResponses.addAll(const [
      SessionStatusResponse(statuses: {"child": SessionStatus.busy(), "sibling": SessionStatus.busy()}),
      SessionStatusResponse(statuses: {"grandchild": SessionStatus.busy()}),
    ]);

    final aborting = _abort(repository);
    expect(repository.childrenReads, isEmpty);
    repository.children["root"] = [
      testSession(id: "child", parentID: "root", pluginId: "cursor"),
      testSession(id: "sibling", parentID: "root", pluginId: "cursor"),
    ];
    repository.children
      ..["child"] = [testSession(id: "grandchild", parentID: "child", pluginId: "cursor")]
      ..["sibling"] = [testSession(id: "must-not-read", parentID: "sibling")];
    rootAbort.complete(ApiResponse.success(false));

    try {
      await aborting;
      fail("expected descendant failure");
    } on SessionAbortDescendantFailureException catch (error) {
      expect(error.cause, same(descendantFailure));
      expect(error.causeStackTrace, same(descendantStack));
    }
    expect(repository.abortedIds, ["root", "child", "sibling", "grandchild"]);
    expect(repository.childrenReads, ["root", "child"]);
  });

  test("unavailable parent retains first failure after active grandchild and sibling settle", () async {
    final repository = _FakeRepository();
    final grandchildAbort = Completer<ApiResponse<bool>>();
    final siblingAbort = Completer<ApiResponse<bool>>();
    repository.children
      ..["root"] = [
        testSession(id: "unavailable", parentID: "root", pluginId: "down"),
        testSession(id: "sibling", parentID: "root", pluginId: "up"),
      ]
      ..["unavailable"] = [testSession(id: "grandchild", parentID: "unavailable", pluginId: "up")];
    repository.abortResponses.addAll({
      "grandchild": () => grandchildAbort.future,
      "sibling": () => siblingAbort.future,
    });
    repository.statusResponses.addAll(const [
      SessionStatusResponse(statuses: {"sibling": SessionStatus.busy()}, unavailablePluginIds: ["down"]),
      SessionStatusResponse(statuses: {"grandchild": SessionStatus.busy()}),
    ]);

    final aborting = _abort(repository);
    await Future<void>.delayed(Duration.zero);
    expect(repository.abortedIds, containsAll(["sibling", "grandchild"]));
    siblingAbort.complete(ApiResponse.success(true));
    grandchildAbort.complete(ApiResponse.success(true));

    try {
      await aborting;
      fail("expected unavailable status failure");
    } on SessionAbortDescendantFailureException catch (error) {
      final cause = error.cause as SessionAbortDescendantStatusUnavailableException;
      expect((cause.sessionId, cause.pluginId), ("unavailable", "down"));
    }
    expect(repository.childrenReads, ["root", "unavailable"]);
  });
}
