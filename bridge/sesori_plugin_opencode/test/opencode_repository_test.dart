import "package:opencode_plugin/opencode_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodeRepository.getSessions", () {
    test("excludes child sessions (non-null parentID)", () async {
      final api = _FakeApi(
        sessions: [
          const Session(
            slug: "slug",
            title: "title",
            version: "v",
            time: SessionTime(created: 0, updated: 0, compacting: null, archived: null),
            id: "parent-1",
            projectID: "p1",
            directory: "/repo",
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
          const Session(
            slug: "slug",
            title: "title",
            version: "v",
            time: SessionTime(created: 0, updated: 0, compacting: null, archived: null),
            id: "child-1",
            projectID: "p1",
            directory: "/repo",
            parentID: "parent-1",
            workspaceID: null,
            path: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
          const Session(
            slug: "slug",
            title: "title",
            version: "v",
            time: SessionTime(created: 0, updated: 0, compacting: null, archived: null),
            id: "parent-2",
            projectID: "p1",
            directory: "/repo",
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
          const Session(
            slug: "slug",
            title: "title",
            version: "v",
            time: SessionTime(created: 0, updated: 0, compacting: null, archived: null),
            id: "child-2",
            projectID: "p1",
            directory: "/repo",
            parentID: "parent-2",
            workspaceID: null,
            path: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final sessions = await repository.getSessions(worktree: "/repo");

      final ids = sessions.map((s) => s.id).toList();
      expect(ids, containsAll(["parent-1", "parent-2"]));
      expect(ids, isNot(contains("child-1")));
      expect(ids, isNot(contains("child-2")));
    });

    test("includes sessions with null parentID", () async {
      final api = _FakeApi(
        sessions: [
          const Session(
            slug: "slug",
            title: "title",
            version: "v",
            time: SessionTime(created: 0, updated: 0, compacting: null, archived: null),
            id: "s1",
            projectID: "p1",
            directory: "/repo",
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
          const Session(
            slug: "slug",
            title: "title",
            version: "v",
            time: SessionTime(created: 0, updated: 0, compacting: null, archived: null),
            id: "s2",
            projectID: "p1",
            directory: "/repo",
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final sessions = await repository.getSessions(worktree: "/repo");

      expect(sessions.map((s) => s.id).toList(), equals(["s1", "s2"]));
    });

    test("excludes child sessions from global sessions too", () async {
      final api = _FakeApi(
        globalSessions: [
          const GlobalSession(
            slug: "slug",
            title: "title",
            version: "v",
            time: GlobalSessionTime(created: 0, updated: 0, compacting: null, archived: null),
            project: null,
            id: "g-parent",
            projectID: "global",
            directory: "/repo",
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
          const GlobalSession(
            slug: "slug",
            title: "title",
            version: "v",
            time: GlobalSessionTime(created: 0, updated: 0, compacting: null, archived: null),
            project: null,
            id: "g-child",
            projectID: "global",
            directory: "/repo",
            parentID: "g-parent",
            workspaceID: null,
            path: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final sessions = await repository.getSessions(worktree: "/repo");

      final ids = sessions.map((s) => s.id).toList();
      expect(ids, contains("g-parent"));
      expect(ids, isNot(contains("g-child")));
    });

    test("filters by worktree directory", () async {
      final api = _FakeApi(
        sessions: [
          const Session(
            slug: "slug",
            title: "title",
            version: "v",
            time: SessionTime(created: 0, updated: 0, compacting: null, archived: null),
            id: "s1",
            projectID: "p1",
            directory: "/repo",
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
          const Session(
            slug: "slug",
            title: "title",
            version: "v",
            time: SessionTime(created: 0, updated: 0, compacting: null, archived: null),
            id: "s2",
            projectID: "p1",
            directory: "/other",
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final sessions = await repository.getSessions(worktree: "/repo");

      expect(sessions.map((s) => s.id).toList(), equals(["s1"]));
    });

    test("sorts by updated time descending", () async {
      final api = _FakeApi(
        sessions: [
          const Session(
            slug: "slug",
            title: "title",
            version: "v",
            id: "old",
            projectID: "p1",
            directory: "/repo",
            time: SessionTime(created: 100, updated: 100, compacting: null, archived: null),
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
          const Session(
            slug: "slug",
            title: "title",
            version: "v",
            id: "new",
            projectID: "p1",
            directory: "/repo",
            time: SessionTime(created: 200, updated: 200, compacting: null, archived: null),
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final sessions = await repository.getSessions(worktree: "/repo");

      expect(sessions.map((s) => s.id).toList(), equals(["new", "old"]));
    });

    test("deduplicates standard and global sessions", () async {
      final api = _FakeApi(
        sessions: [
          const Session(
            slug: "slug",
            title: "title",
            version: "v",
            time: SessionTime(created: 0, updated: 0, compacting: null, archived: null),
            id: "dup",
            projectID: "p1",
            directory: "/repo",
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
        ],
        globalSessions: [
          const GlobalSession(
            slug: "slug",
            title: "title",
            version: "v",
            time: GlobalSessionTime(created: 0, updated: 0, compacting: null, archived: null),
            project: null,
            id: "dup",
            projectID: "global",
            directory: "/repo",
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
          const GlobalSession(
            slug: "slug",
            title: "title",
            version: "v",
            time: GlobalSessionTime(created: 0, updated: 0, compacting: null, archived: null),
            project: null,
            id: "unique",
            projectID: "global",
            directory: "/repo",
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final sessions = await repository.getSessions(worktree: "/repo");

      final ids = sessions.map((s) => s.id).toList();
      expect(ids, containsAll(["dup", "unique"]));
      expect(ids.where((id) => id == "dup").length, equals(1));
    });
  });

  group("OpenCodeRepository.getProjects", () {
    test("ignores the raw project startup timestamp and derives activity from root sessions", () async {
      // OpenCode stamps the raw project update time at server startup, making
      // it newer than actual work. It must not influence project activity.
      final api = _FakeApi(
        projects: [
          const Project(
            sandboxes: <String>[],
            id: "my-project",
            worktree: "/repo",
            time: ProjectTime(created: 1000, updated: 99000, initialized: null),
            vcs: null,
            name: null,
            icon: null,
            commands: null,
          ),
        ],
        globalSessions: [
          const GlobalSession(
            slug: "slug",
            title: "title",
            version: "v",
            project: null,
            id: "s1",
            projectID: "my-project",
            directory: "/repo",
            time: GlobalSessionTime(created: 1500, updated: 9000, compacting: null, archived: null),
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
          const GlobalSession(
            slug: "child",
            title: "child",
            version: "v",
            project: null,
            id: "child",
            projectID: "my-project",
            directory: "/repo",
            time: GlobalSessionTime(created: 1, updated: 100000, compacting: null, archived: null),
            workspaceID: null,
            path: null,
            parentID: "s1",
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      expect(projects, hasLength(1));
      expect(projects.first.project.activity, isNotNull);
      expect(projects.first.project.activity!.updatedAt, equals(9000));
      expect(projects.first.project.activity!.createdAt, equals(1500));
    });

    test("derives activity from global sessions into matching real project", () async {
      // Orphaned global sessions under a directory that also has a real project.
      final api = _FakeApi(
        projects: [
          const Project(
            sandboxes: <String>[],
            id: "my-project",
            worktree: "/repo",
            time: ProjectTime(created: 1000, updated: 2000, initialized: null),
            vcs: null,
            name: null,
            icon: null,
            commands: null,
          ),
        ],
        globalSessions: [
          const GlobalSession(
            slug: "slug",
            title: "title",
            version: "v",
            project: null,
            id: "orphan",
            projectID: "global",
            directory: "/repo",
            time: GlobalSessionTime(created: 500, updated: 3000, compacting: null, archived: null),
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      expect(projects, hasLength(1));
      expect(projects.first.project.activity, isNotNull);
      expect(projects.first.project.activity!.updatedAt, equals(3000));
      expect(projects.first.project.activity!.createdAt, equals(500));
    });

    test("activity is null when no sessions exist", () async {
      final api = _FakeApi(
        projects: [
          const Project(
            sandboxes: <String>[],
            id: "my-project",
            worktree: "/repo",
            time: ProjectTime(created: 1000, updated: 2000, initialized: null),
            vcs: null,
            name: null,
            icon: null,
            commands: null,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      expect(projects, hasLength(1));
      expect(projects.first.project.activity, isNull);
    });

    test("activity is null when nonempty session times are all null", () {
      expect(
        OpenCodeRepository.deriveActivityFromSessionTimes(
          times: const <GlobalSessionTime?>[null, null],
        ),
        isNull,
      );
    });

    test("derives activity from both global and real-project sessions", () async {
      // Project has sessions from both the real project ID and the global
      // project ID (pre-git-init orphans). Both should contribute to the
      // session-derived activity.
      final api = _FakeApi(
        projects: [
          const Project(
            sandboxes: <String>[],
            id: "my-project",
            worktree: "/repo",
            time: ProjectTime(created: 1000, updated: 1000, initialized: null),
            vcs: null,
            name: null,
            icon: null,
            commands: null,
          ),
        ],
        globalSessions: [
          const GlobalSession(
            slug: "slug",
            title: "title",
            version: "v",
            project: null,
            id: "real-session",
            projectID: "my-project",
            directory: "/repo",
            time: GlobalSessionTime(created: 2000, updated: 5000, compacting: null, archived: null),
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
          const GlobalSession(
            slug: "slug",
            title: "title",
            version: "v",
            project: null,
            id: "orphan-session",
            projectID: "global",
            directory: "/repo",
            time: GlobalSessionTime(created: 500, updated: 8000, compacting: null, archived: null),
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      expect(projects, hasLength(1));
      expect(projects.first.project.activity, isNotNull);
      expect(projects.first.project.activity!.updatedAt, equals(8000));
      expect(projects.first.project.activity!.createdAt, equals(500));
    });

    test("creates virtual projects only from global sessions", () async {
      // A directory with only global sessions (no real project entry) should
      // produce a virtual project.
      final api = _FakeApi(
        projects: [
          const Project(
            sandboxes: <String>[],
            id: "other-project",
            worktree: "/other-repo",
            time: ProjectTime(created: 1000, updated: 1000, initialized: null),
            vcs: null,
            name: null,
            icon: null,
            commands: null,
          ),
        ],
        globalSessions: [
          const GlobalSession(
            slug: "slug",
            title: "title",
            version: "v",
            project: null,
            id: "orphan",
            projectID: "global",
            directory: "/no-git-repo",
            time: GlobalSessionTime(created: 500, updated: 3000, compacting: null, archived: null),
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      // Should have the real project + a virtual one.
      expect(projects, hasLength(2));
      final virtual = projects.where((p) => p.project.id == "/no-git-repo");
      expect(virtual, hasLength(1));
      expect(virtual.first.project.activity, isNotNull);
      expect(virtual.first.project.activity!.updatedAt, equals(3000));
      expect(virtual.first.project.activity!.createdAt, equals(500));
    });

    test("does not create virtual project for real-project sessions without matching project", () async {
      // Sessions belonging to a non-global project ID should not produce
      // virtual projects — they already belong to a real project even if the
      // project entry wasn't returned by the API (edge case).
      final api = _FakeApi(
        projects: [],
        globalSessions: [
          const GlobalSession(
            slug: "slug",
            title: "title",
            version: "v",
            project: null,
            id: "s1",
            projectID: "some-real-project",
            directory: "/repo",
            time: GlobalSessionTime(created: 500, updated: 3000, compacting: null, archived: null),
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      // No virtual project should be created for non-global sessions.
      expect(projects, isEmpty);
    });

    test("derives activity from sessions in subdirectories of the worktree", () async {
      // A session started from a subdirectory of the project (e.g. the user
      // ran OpenCode from /repo/packages/foo). The project worktree is /repo.
      // The session's timestamp should still contribute to the project's
      // session-derived activity.
      final api = _FakeApi(
        projects: [
          const Project(
            sandboxes: <String>[],
            id: "my-project",
            worktree: "/repo",
            time: ProjectTime(created: 1000, updated: 1000, initialized: null),
            vcs: null,
            name: null,
            icon: null,
            commands: null,
          ),
        ],
        globalSessions: [
          const GlobalSession(
            slug: "slug",
            title: "title",
            version: "v",
            project: null,
            id: "sub-session",
            projectID: "my-project",
            directory: "/repo/packages/foo",
            time: GlobalSessionTime(created: 2000, updated: 9000, compacting: null, archived: null),
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      expect(projects, hasLength(1));
      expect(projects.first.project.activity, isNotNull);
      expect(projects.first.project.activity!.updatedAt, equals(9000));
      expect(projects.first.project.activity!.createdAt, equals(2000));
    });

    test("attributes sandbox session activity to the canonical project", () async {
      final api = _FakeApi(
        projects: [
          const Project(
            sandboxes: <String>["/moved/repo", "/second/repo", ""],
            id: "my-project",
            worktree: "/repo",
            time: ProjectTime(created: 1000, updated: 1000, initialized: null),
            vcs: null,
            name: null,
            icon: null,
            commands: null,
          ),
        ],
        globalSessions: [
          const GlobalSession(
            slug: "canonical",
            title: "canonical",
            version: "v",
            project: null,
            id: "canonical-session",
            projectID: "my-project",
            directory: "/repo",
            time: GlobalSessionTime(created: 2000, updated: 5000, compacting: null, archived: null),
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
          const GlobalSession(
            slug: "moved",
            title: "moved",
            version: "v",
            project: null,
            id: "moved-session",
            projectID: "global",
            directory: "/moved/repo",
            time: GlobalSessionTime(created: 500, updated: 9000, compacting: null, archived: null),
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
          const GlobalSession(
            slug: "second-move",
            title: "second move",
            version: "v",
            project: null,
            id: "second-moved-session",
            projectID: "global",
            directory: "/second/repo",
            time: GlobalSessionTime(created: 1000, updated: 12000, compacting: null, archived: null),
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
          const GlobalSession(
            slug: "unrelated",
            title: "unrelated",
            version: "v",
            project: null,
            id: "unrelated-session",
            projectID: "global",
            directory: "/unrelated/repo",
            time: GlobalSessionTime(created: 100, updated: 99000, compacting: null, archived: null),
            workspaceID: null,
            path: null,
            parentID: null,
            summary: null,
            cost: null,
            tokens: null,
            share: null,
            agent: null,
            model: null,
            metadata: null,
            permission: null,
            revert: null,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      expect(projects, hasLength(2));
      final canonical = projects.singleWhere((project) => project.project.id == "/repo");
      expect(
        canonical.project.activity,
        equals(const PluginProjectActivity(createdAt: 500, updatedAt: 12000)),
      );
    });

    test("excludes global meta-project from results", () async {
      final api = _FakeApi(
        projects: [
          const Project(
            sandboxes: <String>[],
            id: "global",
            worktree: "/home/user",
            time: ProjectTime(created: 1000, updated: 1000, initialized: null),
            vcs: null,
            name: null,
            icon: null,
            commands: null,
          ),
          const Project(
            sandboxes: <String>[],
            id: "my-project",
            worktree: "/repo",
            time: ProjectTime(created: 2000, updated: 2000, initialized: null),
            vcs: null,
            name: null,
            icon: null,
            commands: null,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      expect(projects, hasLength(1));
      expect(projects.first.project.id, equals("/repo"));
    });
  });

  group("OpenCodeRepository.getCommands", () {
    test("maps OpenCode commands to plugin commands in Layer 2", () async {
      final api = _FakeApi(
        commands: const [
          Command(
            name: "/review-work",
            template: "review {{input}}",
            hints: ["recent changes"],
            description: "Review current branch changes",
            agent: "review-work",
            model: "gpt-5.4",
            provider: "openai",
            source: CommandSource.skill,
            subtask: true,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final commands = await repository.getCommands(projectId: "/repo");

      expect(commands, hasLength(1));
      expect(
        commands.single,
        const PluginCommand(
          name: "/review-work",
          template: "review {{input}}",
          hints: ["recent changes"],
          description: "Review current branch changes",
          agent: "review-work",
          model: "gpt-5.4",
          provider: "openai",
          source: PluginCommandSource.skill,
          subtask: true,
        ),
      );
    });
  });

  group("OpenCodeRepository.getMessages command history", () {
    test("folds manual guidance and typed summary into one retained command", () async {
      final repository = OpenCodeRepository(
        _FakeApi(
          messages: [
            _historyUser(
              id: "guidance",
              created: 900,
              parts: [_historyTextPart(id: "guidance-part", messageId: "guidance", text: "Keep auth decisions")],
            ),
            _historyUser(
              id: "manual-trigger",
              created: 1000,
              parts: [_historyCompactionPart(messageId: "manual-trigger", automatic: false)],
            ),
            _historyAssistant(
              id: "manual-summary",
              parentId: "manual-trigger",
              created: 1100,
              summary: true,
              mode: "compaction",
              parts: [_historyTextPart(id: "summary-part", messageId: "manual-summary", text: "summary")],
            ),
          ],
        ),
      );

      final messages = await repository.getMessages(
        sessionId: "session",
        directory: "/repo",
        acceptedCommands: const [
          PluginCommandInvocationContext(
            invocationId: "manual-invocation",
            name: "compact",
            arguments: "Keep auth decisions",
            acceptedAt: 1200,
            backendMessageId: null,
          ),
        ],
      );

      expect(messages, hasLength(1));
      expect(
        messages.single.info,
        isA<PluginMessageCommand>()
            .having((message) => message.id, "id", "manual-trigger")
            .having((message) => message.origin, "origin", PluginCommandOrigin.manual)
            .having((message) => message.invocationId, "invocationId", "manual-invocation"),
      );
      expect(messages.single.parts.single.messageID, "manual-trigger");
      expect(messages.single.parts.single.text, "summary");
      expect(messages.map((message) => message.info.id), isNot(contains("guidance")));
      expect(messages.map((message) => message.info.id), isNot(contains("manual-summary")));
    });

    test("matches manual compaction when its trigger timestamp follows acceptance", () async {
      final repository = OpenCodeRepository(
        _FakeApi(
          messages: [
            _historyUser(
              id: "guidance",
              created: 900,
              parts: [_historyTextPart(id: "guidance-part", messageId: "guidance", text: "Keep auth decisions")],
            ),
            _historyUser(
              id: "manual-trigger",
              created: 1300,
              parts: [_historyCompactionPart(messageId: "manual-trigger", automatic: false)],
            ),
            _historyAssistant(
              id: "manual-summary",
              parentId: "manual-trigger",
              created: 1400,
              summary: true,
              mode: "compaction",
              parts: [_historyTextPart(id: "summary-part", messageId: "manual-summary", text: "summary")],
            ),
          ],
        ),
      );

      final messages = await repository.getMessages(
        sessionId: "session",
        directory: "/repo",
        acceptedCommands: const [
          PluginCommandInvocationContext(
            invocationId: "manual-invocation",
            name: "compact",
            arguments: "Keep auth decisions",
            acceptedAt: 1200,
            backendMessageId: null,
          ),
        ],
      );

      expect(messages, hasLength(1));
      expect(
        messages.single.info,
        isA<PluginMessageCommand>()
            .having((message) => message.id, "id", "manual-trigger")
            .having((message) => message.arguments, "arguments", "Keep auth decisions")
            .having((message) => message.invocationId, "invocationId", "manual-invocation"),
      );
      expect(messages.single.parts.single.text, "summary");
      expect(messages.map((message) => message.info.id), isNot(contains("guidance")));
    });

    test("pairs multiple manual compactions newest-first", () async {
      final repository = OpenCodeRepository(
        _FakeApi(
          messages: [
            _historyUser(
              id: "older-guidance",
              created: 900,
              parts: [_historyTextPart(id: "older-guidance-part", messageId: "older-guidance", text: "Keep auth")],
            ),
            _historyUser(
              id: "older-trigger",
              created: 1300,
              parts: [_historyCompactionPart(messageId: "older-trigger", automatic: false)],
            ),
            _historyAssistant(
              id: "older-summary",
              parentId: "older-trigger",
              created: 1400,
              summary: true,
              mode: "compaction",
              parts: [_historyTextPart(id: "older-summary-part", messageId: "older-summary", text: "older summary")],
            ),
            _historyUser(
              id: "newer-guidance",
              created: 1900,
              parts: [_historyTextPart(id: "newer-guidance-part", messageId: "newer-guidance", text: "Keep tests")],
            ),
            _historyUser(
              id: "newer-trigger",
              created: 2300,
              parts: [_historyCompactionPart(messageId: "newer-trigger", automatic: false)],
            ),
            _historyAssistant(
              id: "newer-summary",
              parentId: "newer-trigger",
              created: 2400,
              summary: true,
              mode: "compaction",
              parts: [_historyTextPart(id: "newer-summary-part", messageId: "newer-summary", text: "newer summary")],
            ),
          ],
        ),
      );

      final messages = await repository.getMessages(
        sessionId: "session",
        directory: "/repo",
        acceptedCommands: const [
          PluginCommandInvocationContext(
            invocationId: "older-invocation",
            name: "compact",
            arguments: "Keep auth",
            acceptedAt: 1500,
            backendMessageId: null,
          ),
          PluginCommandInvocationContext(
            invocationId: "newer-invocation",
            name: "compact",
            arguments: "Keep tests",
            acceptedAt: 2500,
            backendMessageId: null,
          ),
        ],
      );

      expect(messages, hasLength(2));
      final older = messages.first.info as PluginMessageCommand;
      final newer = messages.last.info as PluginMessageCommand;
      expect(older.id, "older-trigger");
      expect(older.arguments, "Keep auth");
      expect(older.invocationId, "older-invocation");
      expect(messages.first.parts.single.text, "older summary");
      expect(newer.id, "newer-trigger");
      expect(newer.arguments, "Keep tests");
      expect(newer.invocationId, "newer-invocation");
      expect(messages.last.parts.single.text, "newer summary");
      expect(
        messages.map((message) => message.info.id),
        ["older-trigger", "newer-trigger"],
      );
    });

    test("folds automatic compaction without an accepted invocation", () async {
      final repository = OpenCodeRepository(
        _FakeApi(
          messages: [
            _historyUser(
              id: "auto-trigger",
              created: 2000,
              parts: [_historyCompactionPart(messageId: "auto-trigger", automatic: true)],
            ),
            _historyAssistant(
              id: "auto-summary",
              parentId: "auto-trigger",
              created: 2100,
              summary: true,
              mode: "compaction",
              parts: [_historyTextPart(id: "auto-part", messageId: "auto-summary", text: "auto summary")],
            ),
          ],
        ),
      );

      final messages = await repository.getMessages(
        sessionId: "session",
        directory: "/repo",
        acceptedCommands: const [],
      );

      expect(messages, hasLength(1));
      expect(
        messages.single.info,
        isA<PluginMessageCommand>()
            .having((message) => message.origin, "origin", PluginCommandOrigin.automatic)
            .having((message) => message.invocationId, "invocationId", isNull),
      );
      expect(messages.single.parts.single.messageID, "auto-trigger");
    });

    test("reload uses the caller-chosen backend ID and exposes a correlated error as result text", () async {
      const triggerId = "msg_sesori_0123456789abcdef0123456789abcdef";
      final repository = OpenCodeRepository(
        _FakeApi(
          messages: [
            _historyUser(
              id: triggerId,
              created: 3000,
              parts: [_historyTextPart(id: "command-input", messageId: triggerId, text: "review")],
            ),
            _historyAssistant(
              id: "command-error",
              parentId: triggerId,
              created: 3100,
              errorMessage: "Model unavailable",
              parts: const [],
            ),
          ],
        ),
      );

      final messages = await repository.getMessages(
        sessionId: "session",
        directory: "/repo",
        acceptedCommands: const [
          PluginCommandInvocationContext(
            invocationId: "ordinary-invocation",
            name: "review",
            arguments: null,
            acceptedAt: 3000,
            backendMessageId: triggerId,
          ),
        ],
      );

      expect(messages, hasLength(1));
      expect(
        messages.single.info,
        isA<PluginMessageCommand>()
            .having((message) => message.id, "id", triggerId)
            .having((message) => message.invocationId, "invocationId", "ordinary-invocation"),
      );
      expect(messages.single.parts.single.type, PluginMessagePartType.text);
      expect(messages.single.parts.single.text, "Model unavailable");
      expect(messages.single.parts.single.messageID, triggerId);
    });

    test("leaves non-command history unchanged", () async {
      final repository = OpenCodeRepository(
        _FakeApi(
          messages: [
            _historyUser(
              id: "ordinary-user",
              created: 4000,
              parts: [_historyTextPart(id: "user-part", messageId: "ordinary-user", text: "hello")],
            ),
            _historyAssistant(
              id: "ordinary-assistant",
              parentId: "ordinary-user",
              created: 4100,
              parts: [_historyTextPart(id: "assistant-part", messageId: "ordinary-assistant", text: "world")],
            ),
          ],
        ),
      );

      final messages = await repository.getMessages(
        sessionId: "session",
        directory: "/repo",
        acceptedCommands: const [],
      );

      expect(messages, hasLength(2));
      expect(messages.first.info, isA<PluginMessageUser>());
      expect(messages.first.parts.single.text, "hello");
      expect(messages.last.info, isA<PluginMessageAssistant>());
      expect(messages.last.parts.single.messageID, "ordinary-assistant");
      expect(messages.last.parts.single.text, "world");
    });
  });

  group("OpenCodeRepository.createSession", () {
    test("trims directory before calling api and mapping projectID", () async {
      final api = _FakeApi(
        createdSession: const Session(
          slug: "slug",
          version: "v",
          id: "ses-1",
          projectID: "global",
          directory: "/repo",
          parentID: null,
          title: "",
          time: SessionTime(created: 0, updated: 0, compacting: null, archived: null),
          summary: null,
          workspaceID: null,
          path: null,
          cost: null,
          tokens: null,
          share: null,
          agent: null,
          model: null,
          metadata: null,
          permission: null,
          revert: null,
        ),
      );
      final repository = OpenCodeRepository(api);

      final session = await repository.createSession(
        directory: "  /repo  ",
        parentSessionId: "parent-1",
      );

      expect(api.lastCreateDirectory, equals("/repo"));
      expect(api.lastCreateParentSessionId, equals("parent-1"));
      expect(session.projectID, equals("/repo"));
    });
  });

  group("OpenCodeRepository variant passthrough", () {
    test("sendPrompt forwards raw variant", () async {
      final api = _FakeApi();
      final repository = OpenCodeRepository(api);

      await repository.sendPrompt(
        sessionId: "ses-1",
        directory: " /repo ",
        parts: const [PluginPromptPart.text(text: "Continue")],
        agent: "build",
        variant: const PluginSessionVariant(id: "custom-low"),
        model: (providerID: "openai", modelID: "gpt-5.4"),
      );

      expect(api.lastPromptSessionId, equals("ses-1"));
      expect(api.lastPromptDirectory, equals("/repo"));
      expect(api.lastPromptBody?.toJson()["variant"], equals("custom-low"));
    });

    test("sendPrompt omits variant when null", () async {
      final api = _FakeApi();
      final repository = OpenCodeRepository(api);

      await repository.sendPrompt(
        sessionId: "ses-null",
        directory: "/repo",
        parts: const [PluginPromptPart.text(text: "Null")],
        agent: null,
        variant: null,
        model: null,
      );

      expect(api.promptBodies, hasLength(1));
      expect(api.promptBodies.single.toJson().containsKey("variant"), isFalse);
    });

    test("sendCommand forwards raw variant", () async {
      final api = _FakeApi();
      final repository = OpenCodeRepository(api);

      await repository.sendCommand(
        sessionId: "ses-1",
        directory: "/repo",
        messageId: "msg_sesori_0123456789abcdef0123456789abcdef",
        command: "/review-work",
        arguments: "recent changes",
        agent: "reviewer",
        variant: const PluginSessionVariant(id: "xhigh"),
        model: (providerID: "openai", modelID: "gpt-4.1"),
      );

      expect(api.lastCommandSessionId, equals("ses-1"));
      expect(api.lastCommandDirectory, equals("/repo"));
      expect(
        api.lastCommandBody?.toJson()["messageID"],
        equals("msg_sesori_0123456789abcdef0123456789abcdef"),
      );
      expect(api.lastCommandBody?.toJson()["variant"], equals("xhigh"));
    });
  });

  group("OpenCodeRepository.summarize", () {
    test("builds the summarize payload and normalizes the directory", () async {
      final api = _FakeApi();
      final repository = OpenCodeRepository(api);

      await repository.summarize(
        sessionId: "ses-1",
        directory: " /repo ",
        model: (providerID: "openai", modelID: "gpt-4.1"),
      );

      expect(api.lastSummarizeSessionId, equals("ses-1"));
      expect(api.lastSummarizeDirectory, equals("/repo"));
      expect(
        api.lastSummarizeBody?.toJson(),
        equals({"providerID": "openai", "modelID": "gpt-4.1", "auto": false}),
      );
    });
  });

  group("OpenCodeRepository.addCompactionInstructions", () {
    test("persists instructions as a no-reply prompt", () async {
      final api = _FakeApi();
      final repository = OpenCodeRepository(api);

      await repository.addCompactionInstructions(
        sessionId: "ses-1",
        directory: " /repo ",
        instructions: "Keep auth decisions",
        agent: "build",
        variant: const PluginSessionVariant(id: "high"),
        model: (providerID: "openai", modelID: "gpt-4.1"),
      );

      expect(api.lastPromptSessionId, equals("ses-1"));
      expect(api.lastPromptDirectory, equals("/repo"));
      expect(
        api.lastPromptBody?.toJson(),
        equals({
          "parts": [
            {"type": "text", "text": "Keep auth decisions"},
          ],
          "agent": "build",
          "variant": "high",
          "model": {"providerID": "openai", "modelID": "gpt-4.1"},
          "noReply": true,
        }),
      );
    });
  });

  group("Send*Body toJson", () {
    test("SendPromptBody emits variant only when provided", () {
      final withVariant = const SendPromptBody(
        parts: [PluginPromptPart.text(text: "Hello")],
        agent: "build",
        variant: "low",
        model: null,
        noReply: false,
      ).toJson();
      final withoutVariant = const SendPromptBody(
        parts: [PluginPromptPart.text(text: "Hello")],
        agent: "build",
        variant: null,
        model: null,
        noReply: false,
      ).toJson();

      expect(withVariant["variant"], equals("low"));
      expect(withoutVariant.containsKey("variant"), isFalse);
    });

    test("SendCommandBody emits variant only when provided", () {
      final withVariant = const SendCommandBody(
        messageID: "msg_sesori_0123456789abcdef0123456789abcdef",
        command: "/review-work",
        arguments: "recent changes",
        agent: "reviewer",
        variant: "xhigh",
        model: null,
      ).toJson();
      final withoutVariant = const SendCommandBody(
        messageID: null,
        command: "/review-work",
        arguments: "recent changes",
        agent: "reviewer",
        variant: null,
        model: null,
      ).toJson();

      expect(withVariant["variant"], equals("xhigh"));
      expect(withoutVariant.containsKey("variant"), isFalse);
    });
  });
}

SessionMessagesResponseItem _historyUser({
  required String id,
  required int created,
  required List<Map<String, dynamic>> parts,
}) => SessionMessagesResponseItem.fromJson({
  "info": {
    "role": "user",
    "id": id,
    "sessionID": "session",
    "time": {"created": created},
    "agent": "build",
    "model": const {"providerID": "openai", "modelID": "gpt"},
  },
  "parts": parts,
});

SessionMessagesResponseItem _historyAssistant({
  required String id,
  required String parentId,
  required int created,
  required List<Map<String, dynamic>> parts,
  bool? summary,
  String mode = "primary",
  String? errorMessage,
}) => SessionMessagesResponseItem.fromJson({
  "info": {
    "role": "assistant",
    "id": id,
    "sessionID": "session",
    "time": {"created": created},
    "parentID": parentId,
    "modelID": "gpt",
    "providerID": "openai",
    "mode": mode,
    "agent": "build",
    "path": const {"cwd": "/repo", "root": "/repo"},
    "summary": ?summary,
    if (errorMessage != null)
      "error": {
        "name": "UnknownError",
        "data": {"message": errorMessage},
      },
    "cost": 0,
    "tokens": const {
      "input": 0,
      "output": 0,
      "reasoning": 0,
      "cache": {"read": 0, "write": 0},
    },
  },
  "parts": parts,
});

Map<String, dynamic> _historyTextPart({
  required String id,
  required String messageId,
  required String text,
}) => {
  "id": id,
  "sessionID": "session",
  "messageID": messageId,
  "type": "text",
  "text": text,
};

Map<String, dynamic> _historyCompactionPart({
  required String messageId,
  required bool automatic,
}) => {
  "id": "$messageId-compaction",
  "sessionID": "session",
  "messageID": messageId,
  "type": "compaction",
  "auto": automatic,
  "overflow": automatic,
};

class _FakeApi implements OpenCodeApi {
  final List<Session> _sessions;
  final List<GlobalSession> _globalSessions;
  final List<Project> _projects;
  final List<Command> _commands;
  final List<SessionMessagesResponseItem> _messages;
  final Session? _createdSession;
  String? lastCreateDirectory;
  String? lastCreateParentSessionId;
  String? lastPromptSessionId;
  String? lastPromptDirectory;
  SendPromptBody? lastPromptBody;
  final List<SendPromptBody> promptBodies = [];
  String? lastCommandSessionId;
  String? lastCommandDirectory;
  SendCommandBody? lastCommandBody;
  String? lastSummarizeSessionId;
  String? lastSummarizeDirectory;
  SummarizeBody? lastSummarizeBody;

  _FakeApi({
    List<Session>? sessions,
    List<GlobalSession>? globalSessions,
    List<Project>? projects,
    List<Command>? commands,
    List<SessionMessagesResponseItem>? messages,
    Session? createdSession,
  }) : _sessions = sessions ?? [],
       _globalSessions = globalSessions ?? [],
       _projects = projects ?? [],
       _commands = commands ?? [],
       _messages = messages ?? [],
       _createdSession = createdSession;

  @override
  Future<bool> healthCheck() async => true;

  @override
  Future<List<Project>> listProjects() async => _projects;

  @override
  Future<List<Session>> listRootSessions() async => _sessions;

  @override
  Future<List<Session>> listSessions({String? directory, required bool roots}) async => _sessions;

  @override
  Future<List<Command>> listCommands({required String? directory}) async => _commands;

  @override
  Future<Session> createSession({required String directory, String? parentSessionId}) async {
    lastCreateDirectory = directory;
    lastCreateParentSessionId = parentSessionId;
    return _createdSession ??
        const Session(
          slug: "slug",
          version: "v",
          id: "created",
          projectID: "global",
          directory: "/repo",
          parentID: null,
          title: "",
          time: SessionTime(created: 0, updated: 0, compacting: null, archived: null),
          summary: null,
          workspaceID: null,
          path: null,
          cost: null,
          tokens: null,
          share: null,
          agent: null,
          model: null,
          metadata: null,
          permission: null,
          revert: null,
        );
  }

  @override
  Future<Session> getSession({required String sessionId, required String? directory}) async =>
      throw UnimplementedError();

  @override
  Future<Session> updateSession({
    required String sessionId,
    required Map<String, dynamic> body,
    required String? directory,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteSession({required String sessionId, required String? directory}) async {}

  @override
  Future<void> removeWorktree({
    required String directory,
    required String worktreePath,
  }) async {}

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required SendPromptBody body,
    required String? directory,
  }) async {
    lastPromptSessionId = sessionId;
    lastPromptDirectory = directory;
    lastPromptBody = body;
    promptBodies.add(body);
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required SendCommandBody body,
    required String? directory,
  }) async {
    lastCommandSessionId = sessionId;
    lastCommandDirectory = directory;
    lastCommandBody = body;
  }

  @override
  Future<void> summarize({
    required String sessionId,
    required SummarizeBody body,
    required String? directory,
  }) async {
    lastSummarizeSessionId = sessionId;
    lastSummarizeDirectory = directory;
    lastSummarizeBody = body;
  }

  @override
  Future<void> abortSession({required String sessionId, required String? directory}) async {}

  @override
  Future<List<Agent>> listAgents({required String directory}) async => [];

  @override
  Future<List<QuestionRequest>> getPendingQuestions({required String? directory}) async => [];

  @override
  Future<List<PermissionRequest>> getPendingPermissions({required String? directory}) async => [];

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String? directory,
    required QuestionReplyBody body,
  }) async {}

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String? directory,
    required PluginPermissionReply reply,
  }) async {}

  @override
  Future<void> rejectQuestion({
    required String questionId,
    required String? directory,
  }) async {}

  @override
  Future<Project> getProject({required String directory}) async => throw UnimplementedError();

  @override
  Future<List<Session>> getChildren({
    required String sessionId,
    required String? directory,
  }) async => [];

  @override
  Future<List<SessionMessagesResponseItem>> getMessages({
    required String sessionId,
    required String? directory,
  }) async => _messages;

  @override
  Future<List<GlobalSession>> listAllSessions({
    required String? directory,
    required bool roots,
  }) async => _globalSessions;

  @override
  Future<Map<String, SessionStatus>> getSessionStatuses({required String? directory}) async => {};

  @override
  Future<ProviderListResponse> listProviders() async =>
      const ProviderListResponse(all: [], defaultValue: {}, connected: []);

  @override
  Future<ConfigProvidersResponse> listConfigProviders({required String? directory}) async =>
      const ConfigProvidersResponse(providers: [], defaultValue: {});

  @override
  Future<Project> updateProject({
    required String projectId,
    required String directory,
    required Map<String, dynamic> body,
  }) async => throw UnimplementedError();

  @override
  Future<Session> forkSession({
    required String sessionId,
    required String directory,
  }) async => throw UnimplementedError();
}
