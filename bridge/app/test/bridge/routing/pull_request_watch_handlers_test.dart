import "dart:convert";

import "package:sesori_bridge/src/routing/get_pull_request_watches_handler.dart";
import "package:sesori_bridge/src/routing/set_pull_request_watch_auto_merge_handler.dart";
import "package:sesori_bridge/src/routing/stop_pull_request_watch_handler.dart";
import "package:sesori_bridge/src/services/session_view_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:sesori_tool_pr_monitor/sesori_tool_pr_monitor.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  late _Watches watches;

  setUp(() => watches = _Watches());

  Future<RelayResponse> stop({required String repository}) =>
      StopPullRequestWatchHandler(watches: watches, sessionViews: const _Views()).routeForTest(
        makeRequest(
          "POST",
          "/session/pull-request-watch/stop",
          body: jsonEncode(StopPullRequestWatchRequest(sessionId: "s1", repository: repository, number: 7).toJson()),
        ),
      );

  test("stop ends the session's watch and answers with the session", () async {
    final response = await stop(repository: "Sesori/App");

    expect(response.status, 200);
    expect(watches.calls, ["unwatch s1 Sesori/App#7"]);
    expect(Session.fromJson(jsonDecodeMap(response.body ?? "")).id, "s1");
  });

  test("a repository that is not owner/repo is a bad request", () async {
    expect((await stop(repository: "not a repo")).status, 400);
    expect(watches.calls, isEmpty);
  });

  test("auto-merge sets the session's watch, with no Allow, and answers with the session", () async {
    final response = await SetPullRequestWatchAutoMergeHandler(watches: watches, sessionViews: const _Views())
        .routeForTest(
          makeRequest(
            "POST",
            "/session/pull-request-watch/auto-merge",
            body: jsonEncode(
              const SetPullRequestWatchAutoMergeRequest(
                sessionId: "s1",
                repository: "sesori/app",
                number: 7,
                enabled: true,
              ).toJson(),
            ),
          ),
        );

    expect(response.status, 200);
    expect(watches.calls, ["auto-merge s1 sesori/app#7 true"]);
  });

  test("the list route answers with every watch on this bridge", () async {
    final response = await GetPullRequestWatchesHandler(
      sessionViews: const _Views(),
    ).routeForTest(makeRequest("GET", "/pull-request-watches"));

    expect(response.status, 200);
    expect(PullRequestWatchListResponse.fromJson(jsonDecodeMap(response.body ?? "")).watches.single.sessionId, "s1");
  });
}

class _Watches() implements PullRequestWatchService {
  final List<String> calls = [];

  @override
  Future<bool> unwatch({required String sessionId, required PullRequestTarget target}) async {
    calls.add("unwatch $sessionId ${target.displayKey}");
    return true;
  }

  @override
  Future<PullRequestAutoMergeResult> setAutoMerge({
    required String sessionId,
    required PullRequestTarget target,
    required bool enabled,
  }) async {
    calls.add("auto-merge $sessionId ${target.displayKey} $enabled");
    return const PullRequestAutoMergeNotWatched();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class const _Views() implements SessionViewService {
  @override
  Future<Session> get({required String sessionId}) async => Session(
    approvalOverride: null,
    autoContinuation: null,
    branchName: null,
    id: sessionId,
    pluginId: "fake",
    projectID: "/repo",
    directory: "/repo",
    parentID: null,
    forkedFrom: null,
    title: null,
    time: null,
    promptDefaults: null,
    lastUserActivityAt: null,
    pinOrder: null,
    scheduledTask: null,
    interruption: null,
  );

  @override
  Future<PullRequestWatchListResponse> pullRequestWatches() async => const PullRequestWatchListResponse(
    watches: [
      PullRequestWatchListItem(
        sessionId: "s1",
        sessionTitle: "Fix the build",
        projectId: "/repo",
        watch: SessionPullRequestWatch(
          repository: "sesori/app",
          number: 7,
          title: "Fix the build",
          url: "https://github.com/sesori/app/pull/7",
          autoMerge: false,
          status: PullRequestWatchStatus.needsYou(reasons: [PullRequestWatchNeed.ciFailing]),
        ),
      ),
    ],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
