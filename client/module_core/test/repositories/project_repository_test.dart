import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/repositories/models/repo_provider.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  test("project operations delegate to ProjectApi", () async {
    final api = MockProjectApi();
    final filesystemApi = MockFilesystemApi();
    final repository = ProjectRepository(
      api: api,
      filesystemApi: filesystemApi,
      sessionApi: MockSessionApi(),
    );
    const project = Project(id: "project-1", name: "Project 1", path: "/project-1", time: null);
    const projects = Projects(data: [project]);
    const suggestions = FilesystemSuggestions(data: [], path: null);
    const sessions = SessionListResponse(items: []);

    when(api.listProjects).thenAnswer((_) async => ApiResponse.success(projects));
    when(() => api.createProject(path: "/project-1")).thenAnswer((_) async => ApiResponse.success(project));
    when(
      () => api.discoverProject(
        path: "/project-1",
        gitAction: OpenProjectGitAction.initializeGit,
      ),
    ).thenAnswer((_) async => ApiResponse.success(project));
    when(() => api.getProject(projectId: "project-1")).thenAnswer((_) async => ApiResponse.success(project));
    when(() => api.hideProject(projectId: "project-1")).thenAnswer((_) async => ApiResponse.success(null));
    when(
      () => filesystemApi.getSuggestions(prefix: "/projects"),
    ).thenAnswer((_) async => ApiResponse.success(suggestions));
    when(
      () => api.listSessions(projectId: "project-1", waitForPrData: false),
    ).thenAnswer((_) async => ApiResponse.success(sessions));
    when(
      () => api.renameProject(projectId: "project-1", name: "Renamed"),
    ).thenAnswer((_) async => ApiResponse.success(project));

    expect(await repository.listProjects(), ApiResponse<Projects>.success(projects));
    expect(
      await repository.createProject(parentPath: "/", name: "project-1"),
      ApiResponse<Project>.success(project),
    );
    expect(
      await repository.discoverProject(
        path: "/project-1",
        gitAction: OpenProjectGitAction.initializeGit,
      ),
      ApiResponse<Project>.success(project),
    );
    expect(await repository.getProject(projectId: "project-1"), ApiResponse<Project>.success(project));
    expect(await repository.hideProject(projectId: "project-1"), ApiResponse<void>.success(null));
    expect(
      await repository.getFilesystemSuggestions(prefix: "/projects"),
      ApiResponse<FilesystemSuggestions>.success(suggestions),
    );
    expect(
      await repository.listSessions(projectId: "project-1", waitForPrData: false),
      ApiResponse<SessionListResponse>.success(sessions),
    );
    expect(
      await repository.renameProject(projectId: "project-1", name: "Renamed"),
      ApiResponse<Project>.success(project),
    );

    verify(api.listProjects).called(1);
    verify(() => api.createProject(path: "/project-1")).called(1);
    verify(
      () => api.discoverProject(
        path: "/project-1",
        gitAction: OpenProjectGitAction.initializeGit,
      ),
    ).called(1);
    verify(() => api.getProject(projectId: "project-1")).called(1);
    verify(() => api.hideProject(projectId: "project-1")).called(1);
    verify(() => filesystemApi.getSuggestions(prefix: "/projects")).called(1);
    verify(() => api.listSessions(projectId: "project-1", waitForPrData: false)).called(1);
    verify(() => api.renameProject(projectId: "project-1", name: "Renamed")).called(1);
  });

  group("host paths", () {
    test("creates a child with Windows host separators", () async {
      final api = MockProjectApi();
      final repository = ProjectRepository(
        api: api,
        filesystemApi: MockFilesystemApi(),
        sessionApi: MockSessionApi(),
      );
      const project = Project(id: "project-1", name: "Project 1", path: r"C:\projects\project-1", time: null);
      when(
        () => api.createProject(path: r"C:\projects\project-1"),
      ).thenAnswer((_) async => ApiResponse.success(project));

      final response = await repository.createProject(
        parentPath: r"C:\projects",
        name: "project-1",
      );

      expect(response, ApiResponse<Project>.success(project));
      verify(() => api.createProject(path: r"C:\projects\project-1")).called(1);
    });

    test("resolves POSIX and Windows parents without crossing roots", () {
      final repository = ProjectRepository(
        api: MockProjectApi(),
        filesystemApi: MockFilesystemApi(),
        sessionApi: MockSessionApi(),
      );

      expect(repository.parentHostPath(path: "/home/dev/projects"), "/home/dev");
      expect(repository.parentHostPath(path: "/"), isNull);
      expect(repository.parentHostPath(path: r"C:\Users\dev\projects"), r"C:\Users\dev");
      expect(repository.parentHostPath(path: r"C:\"), isNull);
    });
  });

  group("getGitContext", () {
    late MockProjectApi api;
    late ProjectRepository repository;

    setUp(() {
      api = MockProjectApi();
      repository = ProjectRepository(
        api: api,
        filesystemApi: MockFilesystemApi(),
        sessionApi: MockSessionApi(),
      );
    });

    void stubBaseBranch(BaseBranchResponse response) {
      when(
        () => api.getBaseBranch(projectId: "project-1"),
      ).thenAnswer((_) async => ApiResponse.success(response));
    }

    test("maps the wire response into a git context with a classified provider", () async {
      stubBaseBranch(
        const BaseBranchResponse(baseBranch: "main", repoSlug: "org/repo", repoHost: "gitlab.company.com"),
      );

      final response = await repository.getGitContext(projectId: "project-1");

      final context = (response as SuccessResponse<ProjectGitContext>).data;
      expect(context.baseBranch, equals("main"));
      expect(context.repoSlug, equals("org/repo"));
      expect(context.repoProvider, equals(RepoProvider.gitlab));
    });

    test("classifies a missing host as RepoProvider.other", () async {
      stubBaseBranch(const BaseBranchResponse(baseBranch: null, repoSlug: "org/repo", repoHost: null));

      final response = await repository.getGitContext(projectId: "project-1");

      final context = (response as SuccessResponse<ProjectGitContext>).data;
      expect(context.repoProvider, equals(RepoProvider.other));
    });

    test("passes errors through", () async {
      final error = ApiError.generic();
      when(
        () => api.getBaseBranch(projectId: "project-1"),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final response = await repository.getGitContext(projectId: "project-1");

      expect(response, ApiResponse<ProjectGitContext>.error(error));
    });
  });

  test("findSessionContext retains the catalog session plugin identity", () async {
    final api = MockProjectApi();
    final repository = ProjectRepository(
      api: api,
      filesystemApi: MockFilesystemApi(),
      sessionApi: MockSessionApi(),
    );
    const project = Project(id: "project-1", name: "Project", path: "/project", time: null);
    final session = testSession(id: "session-1", pluginId: "plugin-b", title: "Session");
    when(api.listProjects).thenAnswer((_) async => ApiResponse.success(const Projects(data: [project])));
    when(
      () => api.listSessions(projectId: "project-1", waitForPrData: false),
    ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [session])));

    final context = await repository.findSessionContext(sessionId: "session-1");

    expect(context?.projectId, "project-1");
    expect(context?.pluginId, "plugin-b");
    expect(context?.sessionTitle, "Session");
  });

  test("findSessionContext throws the listProjects ApiError", () async {
    final api = MockProjectApi();
    final repository = ProjectRepository(
      api: api,
      filesystemApi: MockFilesystemApi(),
      sessionApi: MockSessionApi(),
    );
    final error = ApiError.generic();
    when(api.listProjects).thenAnswer((_) async => ApiResponse.error(error));

    await expectLater(repository.findSessionContext(sessionId: "session-1"), throwsA(same(error)));
    verifyNever(
      () => api.listSessions(
        projectId: any(named: "projectId"),
        waitForPrData: any(named: "waitForPrData"),
      ),
    );
  });

  test("findSessionContext recovers child session plugin identity", () async {
    final api = MockProjectApi();
    final sessionApi = MockSessionApi();
    final repository = ProjectRepository(
      api: api,
      filesystemApi: MockFilesystemApi(),
      sessionApi: sessionApi,
    );
    const project = Project(id: "project-1", name: "Project", path: "/project", time: null);
    final root = testSession(id: "root", pluginId: "plugin-b", title: "Root");
    final child = testSession(id: "child", pluginId: "plugin-b", title: "Child").copyWith(parentID: "root");
    when(api.listProjects).thenAnswer((_) async => ApiResponse.success(const Projects(data: [project])));
    when(
      () => api.listSessions(projectId: "project-1", waitForPrData: false),
    ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [root])));
    when(
      () => sessionApi.getChildren(sessionId: "root"),
    ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [child])));

    final context = await repository.findSessionContext(sessionId: "child");

    expect(context?.projectId, "project-1");
    expect(context?.pluginId, "plugin-b");
    expect(context?.sessionTitle, "Child");
  });

  test("findSessionContext searches nested children breadth-first without revisiting cycles", () async {
    final api = MockProjectApi();
    final sessionApi = MockSessionApi();
    final repository = ProjectRepository(
      api: api,
      filesystemApi: MockFilesystemApi(),
      sessionApi: sessionApi,
    );
    const project = Project(id: "project-1", name: "Project", path: "/project", time: null);
    final root = testSession(id: "root", pluginId: "plugin-b", title: "Root");
    final child = testSession(id: "child", pluginId: "plugin-b", title: "Child").copyWith(parentID: "root");
    final nested = testSession(
      id: "nested",
      pluginId: "plugin-b",
      title: "Nested",
    ).copyWith(parentID: "child");
    when(api.listProjects).thenAnswer((_) async => ApiResponse.success(const Projects(data: [project])));
    when(
      () => api.listSessions(projectId: "project-1", waitForPrData: false),
    ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [root])));
    when(
      () => sessionApi.getChildren(sessionId: "root"),
    ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [child])));
    when(
      () => sessionApi.getChildren(sessionId: "child"),
    ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [root, nested])));

    final context = await repository.findSessionContext(sessionId: "nested");

    expect(context?.projectId, "project-1");
    expect(context?.pluginId, "plugin-b");
    expect(context?.sessionTitle, "Nested");
    verify(() => sessionApi.getChildren(sessionId: "root")).called(1);
    verify(() => sessionApi.getChildren(sessionId: "child")).called(1);
  });

  test("findSessionContext surfaces a child lookup error when no project matches", () async {
    final api = MockProjectApi();
    final sessionApi = MockSessionApi();
    final repository = ProjectRepository(
      api: api,
      filesystemApi: MockFilesystemApi(),
      sessionApi: sessionApi,
    );
    const project = Project(id: "project-1", name: "Project", path: "/project", time: null);
    final root = testSession(id: "root", pluginId: "plugin-a", title: "Root");
    final error = ApiError.generic();
    when(api.listProjects).thenAnswer((_) async => ApiResponse.success(const Projects(data: [project])));
    when(
      () => api.listSessions(projectId: "project-1", waitForPrData: false),
    ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [root])));
    when(() => sessionApi.getChildren(sessionId: "root")).thenAnswer((_) async => ApiResponse.error(error));

    await expectLater(repository.findSessionContext(sessionId: "missing"), throwsA(same(error)));
  });

  test("findSessionContext returns another project match after a child lookup error", () async {
    final api = MockProjectApi();
    final sessionApi = MockSessionApi();
    final repository = ProjectRepository(
      api: api,
      filesystemApi: MockFilesystemApi(),
      sessionApi: sessionApi,
    );
    const failedProject = Project(id: "failed-project", name: "Failed", path: "/failed", time: null);
    const matchingProject = Project(id: "matching-project", name: "Matching", path: "/matching", time: null);
    final failedRoot = testSession(id: "failed-root", pluginId: "plugin-a", title: "Failed root");
    final matchingRoot = testSession(id: "matching-root", pluginId: "plugin-b", title: "Matching root");
    final target = testSession(id: "target", pluginId: "plugin-b", title: "Target");
    final failedChildren = Completer<ApiResponse<SessionListResponse>>();
    final matchingChildren = Completer<ApiResponse<SessionListResponse>>();
    final failedChildrenRequested = Completer<void>();
    final matchingChildrenRequested = Completer<void>();
    final error = ApiError.generic();

    when(
      api.listProjects,
    ).thenAnswer((_) async => ApiResponse.success(const Projects(data: [failedProject, matchingProject])));
    when(
      () => api.listSessions(projectId: "failed-project", waitForPrData: false),
    ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [failedRoot])));
    when(
      () => api.listSessions(projectId: "matching-project", waitForPrData: false),
    ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [matchingRoot])));
    when(() => sessionApi.getChildren(sessionId: "failed-root")).thenAnswer((_) {
      failedChildrenRequested.complete();
      return failedChildren.future;
    });
    when(() => sessionApi.getChildren(sessionId: "matching-root")).thenAnswer((_) {
      matchingChildrenRequested.complete();
      return matchingChildren.future;
    });

    final lookup = repository.findSessionContext(sessionId: "target");
    await Future.wait([failedChildrenRequested.future, matchingChildrenRequested.future]);
    failedChildren.complete(ApiResponse.error(error));
    await pumpEventQueue();
    matchingChildren.complete(ApiResponse.success(SessionListResponse(items: [target])));

    final context = await lookup;
    await pumpEventQueue();

    expect(context?.projectId, "matching-project");
    expect(context?.pluginId, "plugin-b");
    expect(context?.sessionTitle, "Target");
  });

  test("findSessionContext logs a root list error and searches other projects", () async {
    final api = MockProjectApi();
    final repository = ProjectRepository(
      api: api,
      filesystemApi: MockFilesystemApi(),
      sessionApi: MockSessionApi(),
    );
    const failedProject = Project(id: "failed-project", name: "Failed", path: "/failed", time: null);
    const matchingProject = Project(id: "matching-project", name: "Matching", path: "/matching", time: null);
    final target = testSession(id: "target", pluginId: "plugin-b", title: "Target");
    final error = ApiError.generic();
    final logs = <String>[];

    when(
      api.listProjects,
    ).thenAnswer((_) async => ApiResponse.success(const Projects(data: [failedProject, matchingProject])));
    when(
      () => api.listSessions(projectId: "failed-project", waitForPrData: false),
    ).thenAnswer((_) async => ApiResponse.error(error));
    when(
      () => api.listSessions(projectId: "matching-project", waitForPrData: false),
    ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [target])));

    final context = await runZoned(
      () => repository.findSessionContext(sessionId: "target"),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logs.add(line),
      ),
    );

    expect(context?.projectId, "matching-project");
    expect(logs, contains(allOf(contains("failed-project"), contains(error.toString()))));
  });

  test("findSessionContext returns a match without waiting for an unrelated child search", () async {
    final api = MockProjectApi();
    final sessionApi = MockSessionApi();
    final repository = ProjectRepository(
      api: api,
      filesystemApi: MockFilesystemApi(),
      sessionApi: sessionApi,
    );
    const blockedProject = Project(id: "blocked-project", name: "Blocked", path: "/blocked", time: null);
    const matchingProject = Project(id: "matching-project", name: "Matching", path: "/matching", time: null);
    final blockedRoot = testSession(id: "blocked-root", pluginId: "plugin-a", title: "Blocked root");
    final blockedChild = testSession(id: "blocked-child", pluginId: "plugin-a", title: "Blocked child");
    final matchingRoot = testSession(id: "matching-root", pluginId: "plugin-b", title: "Matching root");
    final target = testSession(id: "target", pluginId: "plugin-b", title: "Target");
    final blockedChildren = Completer<ApiResponse<SessionListResponse>>();
    final matchingChildrenRequested = Completer<void>();

    when(
      api.listProjects,
    ).thenAnswer((_) async => ApiResponse.success(const Projects(data: [blockedProject, matchingProject])));
    when(
      () => api.listSessions(projectId: "blocked-project", waitForPrData: false),
    ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [blockedRoot])));
    when(
      () => api.listSessions(projectId: "matching-project", waitForPrData: false),
    ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [matchingRoot])));
    when(() => sessionApi.getChildren(sessionId: "blocked-root")).thenAnswer((_) => blockedChildren.future);
    when(() => sessionApi.getChildren(sessionId: "matching-root")).thenAnswer((_) async {
      matchingChildrenRequested.complete();
      return ApiResponse.success(SessionListResponse(items: [target]));
    });
    when(
      () => sessionApi.getChildren(sessionId: "blocked-child"),
    ).thenAnswer((_) async => ApiResponse.success(const SessionListResponse(items: [])));

    final lookup = repository.findSessionContext(sessionId: "target");
    final observedResult = Completer<ProjectSessionContext?>();
    unawaited(lookup.then(observedResult.complete));
    await matchingChildrenRequested.future;
    await pumpEventQueue();
    final completedBeforeUnblocking = observedResult.isCompleted;

    blockedChildren.complete(ApiResponse.success(SessionListResponse(items: [blockedChild])));
    final context = await lookup;
    await pumpEventQueue();

    expect(completedBeforeUnblocking, isTrue);
    expect(context?.projectId, "matching-project");
    expect(context?.pluginId, "plugin-b");
    expect(context?.sessionTitle, "Target");
    verifyNever(() => sessionApi.getChildren(sessionId: "blocked-child"));
  });
}
