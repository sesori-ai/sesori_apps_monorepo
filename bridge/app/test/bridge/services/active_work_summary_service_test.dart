import "dart:async";

import "package:sesori_bridge/src/bridge/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/bridge/services/active_work_summary_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../routing/routing_test_helpers.dart";

class _FakeSessionRepository extends FakeSessionRepository {
  Future<List<ProjectActivitySummary>> Function()? loadSummaries;
  Future<List<StoredSession>> Function(String projectId)? loadStoredSessions;

  _FakeSessionRepository() : super(plugin: FakeBridgePlugin());

  @override
  Future<List<ProjectActivitySummary>> getProjectActivitySummaries() {
    return loadSummaries!();
  }

  @override
  Future<List<StoredSession>> getStoredSessionsByProjectId({required String projectId}) {
    return loadStoredSessions!(projectId);
  }
}

void main() {
  late _FakeSessionRepository repository;
  late ActiveWorkSummaryService service;

  setUp(() {
    repository = _FakeSessionRepository();
    service = ActiveWorkSummaryService(
      sessionRepository: repository,
      retryDelay: Duration.zero,
    );
  });

  tearDown(() => service.dispose());

  test("orders active projects and sessions from persisted user interaction", () async {
    repository.loadSummaries = () async => const [
      ProjectActivitySummary(
        id: "project-old",
        activeSessions: [
          ActiveSession(id: "session-null"),
          ActiveSession(id: "session-old"),
        ],
      ),
      ProjectActivitySummary(
        id: "project-new",
        activeSessions: [ActiveSession(id: "session-new")],
      ),
      ProjectActivitySummary(id: "project-empty", activeSessions: []),
    ];
    repository.loadStoredSessions = (projectId) async {
      return switch (projectId) {
        "project-old" => [
          _stored(id: "session-null", projectId: "project-old", parentSessionId: null, interactionAt: null),
          _stored(id: "session-old", projectId: "project-old", parentSessionId: null, interactionAt: 100),
          _stored(id: "child", projectId: "project-old", parentSessionId: "session-old", interactionAt: 500),
        ],
        "project-new" => [
          _stored(id: "session-new", projectId: "project-new", parentSessionId: null, interactionAt: 200),
          _stored(id: "archived-recent", projectId: "project-new", parentSessionId: null, interactionAt: 300),
        ],
        _ => <StoredSession>[],
      };
    };

    final result = await service.refresh();

    expect(result.projects.map((project) => project.id), ["project-new", "project-old"]);
    expect(result.projects.last.activeSessions.map((session) => session.id), ["session-old", "session-null"]);
  });

  test("inactive sessions do not contribute to project rank", () async {
    repository.loadSummaries = () async => const [
      ProjectActivitySummary(
        id: "project-inactive-newest",
        activeSessions: [ActiveSession(id: "active-old")],
      ),
      ProjectActivitySummary(
        id: "project-active-newest",
        activeSessions: [ActiveSession(id: "active-new")],
      ),
    ];
    repository.loadStoredSessions = (projectId) async {
      return switch (projectId) {
        "project-inactive-newest" => [
          _stored(id: "active-old", projectId: projectId, parentSessionId: null, interactionAt: 100),
          _stored(id: "inactive", projectId: projectId, parentSessionId: null, interactionAt: 1000),
        ],
        "project-active-newest" => [
          _stored(id: "active-new", projectId: projectId, parentSessionId: null, interactionAt: 200),
        ],
        _ => <StoredSession>[],
      };
    };

    final result = await service.refresh();

    expect(result.projects.map((project) => project.id), [
      "project-active-newest",
      "project-inactive-newest",
    ]);
  });

  test("does not publish an unchanged snapshot twice", () async {
    _stubSingleProject(repository);
    final published = <List<ProjectActivitySummary>>[];
    final subscription = service.changedSnapshots.listen(published.add);

    await service.refresh();
    await service.refresh();

    expect(published, hasLength(1));
    await subscription.cancel();
  });

  test("a trigger during a build forces a subsequent committed snapshot", () async {
    final firstBuild = Completer<void>();
    var buildCount = 0;
    repository.loadSummaries = () async {
      buildCount++;
      if (buildCount == 1) await firstBuild.future;
      return [
        ProjectActivitySummary(
          id: "project",
          activeSessions: [ActiveSession(id: buildCount == 1 ? "old" : "new")],
        ),
      ];
    };
    repository.loadStoredSessions = (_) async => [
      _stored(id: "old", projectId: "project", parentSessionId: null, interactionAt: 1),
      _stored(id: "new", projectId: "project", parentSessionId: null, interactionAt: 2),
    ];

    final firstRefresh = service.refresh();
    final secondRefresh = service.refresh();
    firstBuild.complete();
    await Future.wait([firstRefresh, secondRefresh]);

    expect(buildCount, 2);
    expect(service.currentSnapshot!.single.activeSessions.single.id, "new");
  });

  test("a failed build preserves dirty state and retries", () async {
    var buildCount = 0;
    repository.loadSummaries = () async {
      buildCount++;
      if (buildCount == 1) throw StateError("temporary");
      return const [
        ProjectActivitySummary(
          id: "project",
          activeSessions: [ActiveSession(id: "session")],
        ),
      ];
    };
    repository.loadStoredSessions = (_) async => [
      _stored(id: "session", projectId: "project", parentSessionId: null, interactionAt: 1),
    ];

    await service.refresh();
    for (var i = 0; i < 10 && service.currentSnapshot == null; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(buildCount, 2);
    expect(service.currentSnapshot, isNotNull);
  });

  test("dispose waits for an in-flight refresh", () async {
    final buildBlock = Completer<void>();
    repository.loadSummaries = () async {
      await buildBlock.future;
      return const [];
    };
    repository.loadStoredSessions = (_) async => const [];

    final refresh = service.refresh();
    var disposed = false;
    final dispose = service.dispose().then((_) => disposed = true);
    await Future<void>.delayed(Duration.zero);

    expect(disposed, isFalse);

    buildBlock.complete();
    await Future.wait([refresh, dispose]);
    expect(disposed, isTrue);
  });
}

void _stubSingleProject(_FakeSessionRepository repository) {
  repository.loadSummaries = () async => const [
    ProjectActivitySummary(
      id: "project",
      activeSessions: [ActiveSession(id: "session")],
    ),
  ];
  repository.loadStoredSessions = (_) async => [
    _stored(id: "session", projectId: "project", parentSessionId: null, interactionAt: 1),
  ];
}

StoredSession _stored({
  required String id,
  required String projectId,
  required String? parentSessionId,
  required int? interactionAt,
}) {
  return StoredSession(
    id: id,
    backendSessionId: id,
    pluginId: "fake",
    projectId: projectId,
    parentSessionId: parentSessionId,
    directory: projectId,
    worktreePath: null,
    branchName: null,
    isDedicated: false,
    archivedAt: null,
    baseBranch: null,
    baseCommit: null,
    lastUserInteractionAt: interactionAt,
  );
}
