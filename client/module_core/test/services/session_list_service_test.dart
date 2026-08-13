import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/services/models/session_activity_info.dart";
import "package:sesori_dart_core/src/services/session_activity_calculator.dart";
import "package:sesori_dart_core/src/services/session_list_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockProjectRepository() extends Mock implements ProjectRepository;

void main() {
  test("running sessions use activity markers while inactive sessions stay timestamp ordered", () {
    final service = SessionListService(
      repository: _MockProjectRepository(),
      activityCalculator: const SessionActivityCalculator(),
    );

    final result = service.visibleSessions(
      sessions: [
        _session(id: "running-new-update", title: "Zulu", updatedAt: 400),
        _session(id: "waiting", title: "Alpha", updatedAt: 300),
        _session(id: "inactive", title: "Beta", updatedAt: 200),
        _session(id: "running-new-activity", title: "Alpha", updatedAt: 100),
      ],
      showArchived: true,
      activityBySessionId: const {
        "running-new-update": SessionActivityInfo(isRetrying: true),
        "waiting": SessionActivityInfo(awaitingInput: true),
        "running-new-activity": SessionActivityInfo(mainAgentRunning: true),
      },
      listStateBySessionId: const {
        "running-new-update": (unseen: false, lastUserActivityAt: 10),
        "running-new-activity": (unseen: true, lastUserActivityAt: 20),
      },
    );

    expect(
      result.map((session) => session.id),
      ["running-new-activity", "running-new-update", "waiting", "inactive"],
    );
  });

  test("running sessions use REST markers before updated-time fallback", () {
    final service = SessionListService(
      repository: _MockProjectRepository(),
      activityCalculator: const SessionActivityCalculator(),
    );

    final result = service.visibleSessions(
      sessions: [
        _session(id: "new-update", title: "B", updatedAt: 20).copyWith(lastUserActivityAt: 5),
        _session(id: "new-activity", title: "A", updatedAt: 10).copyWith(lastUserActivityAt: 15),
      ],
      showArchived: true,
      activityBySessionId: const {
        "new-update": SessionActivityInfo(mainAgentRunning: true),
        "new-activity": SessionActivityInfo(mainAgentRunning: true),
      },
      listStateBySessionId: const {},
    );

    expect(result.map((session) => session.id), ["new-activity", "new-update"]);
  });

  test("running marker fallback and timestamp ties use session ID", () {
    final service = SessionListService(
      repository: _MockProjectRepository(),
      activityCalculator: const SessionActivityCalculator(),
    );

    final result = service.visibleSessions(
      sessions: [
        _session(id: "running-b", title: "B", updatedAt: 10),
        _session(id: "running-a", title: "A", updatedAt: 10),
        _session(id: "inactive-b", title: "B", updatedAt: 5),
        _session(id: "inactive-a", title: "A", updatedAt: 5),
      ],
      showArchived: true,
      activityBySessionId: const {
        "running-a": SessionActivityInfo(backgroundTaskCount: 1),
        "running-b": SessionActivityInfo(mainAgentRunning: true),
      },
      listStateBySessionId: const {},
    );

    expect(
      result.map((session) => session.id),
      ["running-a", "running-b", "inactive-a", "inactive-b"],
    );
  });

  test("session updates preserve REST PR history when the event omits it", () {
    final service = SessionListService(
      repository: _MockProjectRepository(),
      activityCalculator: const SessionActivityCalculator(),
    );
    const existingHistory = PullRequestInfo(
      number: 690,
      url: "https://github.com/sesori-ai/sesori_apps_monorepo/pull/690",
      title: "Merged pull request",
      state: PrState.merged,
      mergeableStatus: PrMergeableStatus.unknown,
      reviewDecision: PrReviewDecision.unknown,
      checkStatus: PrCheckStatus.success,
    );
    const incomingPullRequest = PullRequestInfo(
      number: 698,
      url: "https://github.com/sesori-ai/sesori_apps_monorepo/pull/698",
      title: "Open pull request",
      state: PrState.open,
      mergeableStatus: PrMergeableStatus.mergeable,
      reviewDecision: PrReviewDecision.unknown,
      checkStatus: PrCheckStatus.pending,
    );
    final existing = _session(id: "session", title: "Original", updatedAt: 1).copyWith(
      pullRequestHistory: const [existingHistory],
      lastUserActivityAt: 20,
    );
    final incoming = _session(id: "session", title: "Updated", updatedAt: 2).copyWith(
      pullRequest: incomingPullRequest,
      lastUserActivityAt: 10,
    );

    final result = service.applySessionUpdatedEvent(
      sessions: [existing],
      existingSession: existing,
      session: incoming,
    );

    expect(result.single.pullRequest, incomingPullRequest);
    expect(result.single.pullRequestHistory, const [existingHistory]);
    expect(result.single.lastUserActivityAt, 20);
  });
}

Session _session({required String id, required String title, required int updatedAt}) {
  return Session(
    id: id,
    projectID: "project",
    directory: "/project",
    parentID: null,
    title: title,
    time: SessionTime(created: 1, updated: updatedAt, archived: null),
    pullRequest: null,
    promptDefaults: null,
    branchName: null,
    lastUserActivityAt: null,
  );
}
