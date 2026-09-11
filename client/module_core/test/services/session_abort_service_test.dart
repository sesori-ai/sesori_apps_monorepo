import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/src/repositories/models/session_abort_not_accepted_exception.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/services/session_abort_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockSessionApi() extends Mock implements SessionApi;

class _FakeRepository() extends SessionRepository {
  this : super(api: _MockSessionApi());

  final abortedIds = <String>[];
  final abortResponses = <String, Future<ApiResponse<bool>> Function()>{};
  final abortErrors = <String, Object>{};
  final children = <String, List<Session>>{};
  Map<String, SessionStatus> statuses = const {};
  @override
  Future<ApiResponse<bool>> abortSession({
    required String sessionId,
    required SessionAbortSubAgentPolicy subAgents,
  }) async {
    abortedIds.add(sessionId);
    final error = abortErrors[sessionId];
    if (error != null) throw error;
    return await (abortResponses[sessionId]?.call() ?? Future.value(ApiResponse.success(false)));
  }

  @override
  Future<ApiResponse<SessionListResponse>> getChildren({required String sessionId}) async =>
      ApiResponse.success(SessionListResponse(items: children[sessionId] ?? const []));
  @override
  Future<ApiResponse<SessionStatusResponse>> getSessionStatuses() async =>
      ApiResponse.success(SessionStatusResponse(statuses: statuses));
}

void main() {
  test("fresh nested fallback wraps refusal after root success", () async {
    final repository = _FakeRepository();
    final rootAbort = Completer<ApiResponse<bool>>();
    repository.abortResponses["root"] = () => rootAbort.future;
    const grandchild = Session(
      id: "grandchild",
      projectID: "project",
      directory: "/repo",
      parentID: "new-child",
      title: null,
      time: null,
      pullRequest: null,
      promptDefaults: null,
      branchName: null,
      lastUserActivityAt: null,
    );
    const refusal = SessionAbortRefusal(
      kind: SessionAbortRefusalKind.notPerformed,
      reason: SessionAbortRefusalReason.residentWorkCompletionUnknown,
    );
    final grandchildFailure = SessionAbortNotAcceptedException(refusal: refusal, innerError: StateError("child 409"));
    repository
      ..children["new-child"] = [grandchild]
      ..statuses = const {"new-child": SessionStatus.busy(), "grandchild": SessionStatus.busy()}
      ..abortErrors["grandchild"] = grandchildFailure;
    var currentStatuses = const <String, SessionStatus>{"old-child": SessionStatus.idle()};
    final aborting = SessionAbortService(repository: repository).abortSession(
      sessionId: "root",
      subAgents: SessionAbortSubAgentPolicy.stop,
      childStatuses: const {"old-child": SessionStatus.busy()},
      readCurrentChildStatuses: () => currentStatuses,
    );
    currentStatuses = const {"new-child": SessionStatus.busy()};
    rootAbort.complete(ApiResponse.success(false));
    await expectLater(
      aborting,
      throwsA(
        isA<SessionAbortDescendantFailureException>().having(
          (error) => error.cause,
          "cause",
          same(grandchildFailure),
        ),
      ),
    );
    expect(repository.abortedIds, ["root", "new-child", "grandchild"]);
  });

  test("request snapshot remains fallback when Cubit is no longer loaded", () async {
    final repository = _FakeRepository();
    await SessionAbortService(repository: repository).abortSession(
      sessionId: "root",
      subAgents: SessionAbortSubAgentPolicy.stop,
      childStatuses: const {"child": SessionStatus.busy()},
      readCurrentChildStatuses: () => null,
    );
    expect(repository.abortedIds, ["root", "child"]);
  });
}
