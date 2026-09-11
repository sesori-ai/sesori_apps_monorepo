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
  int statusReads = 0;

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
      ApiResponse.success(statusResponses[statusReads++]);
}

Future<void> _abort(_FakeRepository repository) => SessionAbortService(
  repository: repository,
).abortSession(sessionId: "root", subAgents: SessionAbortSubAgentPolicy.stop);

void main() {
  test("fresh traversal settles nested and sibling aborts after parent abort failure", () async {
    final repository = _FakeRepository();
    final rootAbort = Completer<ApiResponse<bool>>();
    final descendantFailure = StateError("child 409");
    repository.abortResponses.addAll({
      "root": () => rootAbort.future,
      "child": () => Future.error(descendantFailure),
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
    repository.children["child"] = [testSession(id: "grandchild", parentID: "child", pluginId: "cursor")];
    rootAbort.complete(ApiResponse.success(false));

    try {
      await aborting;
      fail("expected descendant failure");
    } on SessionAbortDescendantFailureException catch (error) {
      expect(error.cause, same(descendantFailure));
    }
    expect(repository.abortedIds, ["root", "child", "sibling", "grandchild"]);
    expect(repository.childrenReads, ["root", "child"]);
  });

  test("childless root avoids status reads and handled descendant prunes its branch", () async {
    final childlessRepository = _FakeRepository();
    await _abort(childlessRepository);
    expect(childlessRepository.statusReads, 0);

    final descendantHandled = _FakeRepository();
    descendantHandled.children["root"] = [testSession(id: "child", parentID: "root", pluginId: "cursor")];
    descendantHandled.children["child"] = [testSession(id: "must-not-read", parentID: "child")];
    descendantHandled.abortResponses["child"] = () async => ApiResponse.success(true);
    descendantHandled.statusResponses.add(
      const SessionStatusResponse(statuses: {"child": SessionStatus.retry(attempt: 1, message: "retry", next: 1)}),
    );
    await _abort(descendantHandled);
    expect(descendantHandled.childrenReads, ["root"]);
  });

  test("empty unavailable snapshot fails while available sibling branch completes", () async {
    final repository = _FakeRepository();
    final descendantAbort = Completer<ApiResponse<bool>>();
    repository.children["root"] = [
      testSession(id: "uncertain", parentID: "root", pluginId: "down"),
      testSession(id: "available", parentID: "root", pluginId: "up"),
    ];
    repository.children["available"] = [testSession(id: "active", parentID: "available", pluginId: "up")];
    repository.abortResponses["active"] = () => descendantAbort.future;
    repository.statusResponses.addAll(const [
      SessionStatusResponse(statuses: {}, unavailablePluginIds: ["down", "unrelated"]),
      SessionStatusResponse(statuses: {"active": SessionStatus.busy()}),
    ]);

    final aborting = _abort(repository);
    await Future<void>.delayed(Duration.zero);
    expect(repository.abortedIds, contains("active"));
    descendantAbort.complete(ApiResponse.success(true));

    try {
      await aborting;
      fail("expected unavailable status failure");
    } on SessionAbortDescendantFailureException catch (error) {
      final cause = error.cause as SessionAbortDescendantStatusUnavailableException;
      expect(cause.pluginId, "down");
    }
    expect(repository.abortedIds, ["root", "active"]);
    expect(repository.childrenReads, ["root", "available"]);
  });
}
