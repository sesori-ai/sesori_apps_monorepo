import "package:opencode_plugin/opencode_plugin.dart";
import "package:opencode_plugin/src/models/openapi/compaction_part.g.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/fake_open_code_api.dart";
import "support/open_code_fixtures.dart";

void main() {
  group("OpenCodeRepository.getProject", () {
    test("maps OpenCode's global project to a folder-specific virtual project", () async {
      final api = FakeOpenCodeApi(
        currentProject: openCodeProject(
          id: "global",
          worktree: "/",
          name: "Global",
        ),
      );
      final repository = OpenCodeRepository(api);

      final project = await repository.getProject(directory: "/projects/plain-folder");

      expect(api.lastGetProjectDirectory, "/projects/plain-folder");
      expect(project.id, "/projects/plain-folder");
      expect(project.directory, "/projects/plain-folder");
      expect(project.name, "plain-folder");
    });

    test("keeps a Git project's canonical worktree identity", () async {
      final api = FakeOpenCodeApi(
        currentProject: openCodeProject(
          id: "project-1",
          worktree: "/projects/original",
          name: "Repository",
        ),
      );
      final repository = OpenCodeRepository(api);

      final project = await repository.getProject(directory: "/projects/moved");

      expect(project.id, "/projects/original");
      expect(project.directory, "/projects/moved");
      expect(project.name, "Repository");
    });
  });

  group("OpenCodeRepository.renameProject", () {
    test("renames a virtual folder without updating the shared global project", () async {
      final api = FakeOpenCodeApi(
        currentProject: openCodeProject(
          id: "global",
          worktree: "/",
          name: "Global",
        ),
      );
      final repository = OpenCodeRepository(api);

      final project = await repository.renameProject(
        directory: "/projects/plain-folder",
        name: "Plain Project",
      );

      expect(api.updateProjectCalls, 0);
      expect(project.id, "/projects/plain-folder");
      expect(project.directory, "/projects/plain-folder");
      expect(project.name, "Plain Project");
    });
  });

  group("OpenCodeRepository.getSessions", () {
    test("excludes child sessions (non-null parentID)", () async {
      final api = FakeOpenCodeApi(
        sessions: [
          openCodeSession(id: "parent-1", directory: "/repo"),
          openCodeSession(id: "child-1", directory: "/repo", parentID: "parent-1"),
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
      final api = FakeOpenCodeApi(
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
      final api = FakeOpenCodeApi(
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
      final api = FakeOpenCodeApi(
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
      final api = FakeOpenCodeApi(
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
      final api = FakeOpenCodeApi(
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
      final api = FakeOpenCodeApi(
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
      final api = FakeOpenCodeApi(
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
      final api = FakeOpenCodeApi(
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
      final api = FakeOpenCodeApi(
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
      final api = FakeOpenCodeApi(
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
      final api = FakeOpenCodeApi(
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
      final api = FakeOpenCodeApi(
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
      final api = FakeOpenCodeApi(
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
      final api = FakeOpenCodeApi(
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
      final api = FakeOpenCodeApi(
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

  group("OpenCodeRepository.createSession", () {
    test("trims directory before calling api and mapping projectID", () async {
      final api = FakeOpenCodeApi(
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

  group("OpenCodeRepository message reservation", () {
    test("lets OpenCode name an empty non-renderable message", () async {
      final api = FakeOpenCodeApi();
      final repository = OpenCodeRepository(api);

      final messageId = await repository.reserveMessage(
        sessionId: "ses-1",
        directory: " /repo ",
        agent: "build",
        variant: const PluginSessionVariant(id: "low"),
        model: (providerID: "openai", modelID: "gpt-4.1"),
      );

      expect(messageId, equals("msg-reserved"));
      expect(api.lastPromptDirectory, equals("/repo"));
      expect(
        api.lastPromptBody?.toJson(),
        equals({
          "parts": <dynamic>[],
          "agent": "build",
          "variant": "low",
          "model": {"providerID": "openai", "modelID": "gpt-4.1"},
          "noReply": true,
        }),
      );
    });

    test("reserves and converts the exact placeholder part for compaction", () async {
      final api = FakeOpenCodeApi();
      final repository = OpenCodeRepository(api);

      final reservation = await repository.reserveCompactionMessage(
        sessionId: "ses-1",
        directory: "/repo",
        userVisibleArguments: "  Keep auth decisions  ",
        agent: "build",
        variant: null,
        model: (providerID: "openai", modelID: "gpt-4.1"),
      );
      await repository.convertReservedPartToCompaction(
        sessionId: "ses-1",
        directory: "/repo",
        messageId: reservation.messageId,
        partId: reservation.partId,
      );

      expect(reservation, equals((messageId: "msg-reserved", partId: "prt-reserved")));
      expect(
        api.lastPromptBody?.toJson()["parts"],
        equals([
          {"type": "text", "text": ""},
          {"type": "text", "text": "Keep auth decisions"},
        ]),
      );
      expect(api.lastUpdatedMessageId, equals("msg-reserved"));
      expect(api.lastUpdatedPartId, equals("prt-reserved"));
      expect(api.lastUpdatedPart, isA<CompactionPart>());
      expect(
        api.lastUpdatedPart?.toJson(),
        equals({
          "id": "prt-reserved",
          "sessionID": "ses-1",
          "messageID": "msg-reserved",
          "type": "compaction",
          "auto": false,
        }),
      );
    });

    test("deletes a rejected reservation by exact message id", () async {
      final api = FakeOpenCodeApi();
      final repository = OpenCodeRepository(api);

      await repository.deleteMessage(
        sessionId: "ses-1",
        directory: "/repo",
        messageId: "msg-reserved",
      );

      expect(api.lastDeletedMessageId, equals("msg-reserved"));
    });
  });

  group("OpenCodeRepository variant passthrough", () {
    test("sendPrompt forwards raw variant", () async {
      final api = FakeOpenCodeApi();
      final repository = OpenCodeRepository(api);

      await repository.sendPrompt(
        messageId: null,
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
      final api = FakeOpenCodeApi();
      final repository = OpenCodeRepository(api);

      await repository.sendPrompt(
        messageId: null,
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
      final api = FakeOpenCodeApi();
      final repository = OpenCodeRepository(api);

      await repository.sendCommand(
        messageId: null,
        sessionId: "ses-1",
        directory: "/repo",
        command: "/review-work",
        arguments: "recent changes",
        agent: "reviewer",
        variant: const PluginSessionVariant(id: "xhigh"),
        model: (providerID: "openai", modelID: "gpt-4.1"),
      );

      expect(api.lastCommandSessionId, equals("ses-1"));
      expect(api.lastCommandDirectory, equals("/repo"));
      expect(api.lastCommandBody?.toJson()["variant"], equals("xhigh"));
    });
  });

  group("OpenCodeRepository.addCompactionInstructions", () {
    test("persists instructions as a no-reply prompt", () async {
      final api = FakeOpenCodeApi();
      final repository = OpenCodeRepository(api);

      await repository.addCompactionInstructions(
        messageId: null,
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
            {"type": "text", "text": "Keep auth decisions", "synthetic": true},
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
        messageID: null,
        parts: [PluginPromptPart.text(text: "Hello")],
        agent: "build",
        variant: "low",
        model: null,
        noReply: false,
        syntheticText: false,
      ).toJson();
      final withoutVariant = const SendPromptBody(
        messageID: null,
        parts: [PluginPromptPart.text(text: "Hello")],
        agent: "build",
        variant: null,
        model: null,
        noReply: false,
        syntheticText: false,
      ).toJson();

      expect(withVariant["variant"], equals("low"));
      expect(withoutVariant.containsKey("variant"), isFalse);
    });

    test("SendCommandBody emits variant only when provided", () {
      final withVariant = const SendCommandBody(
        messageID: null,
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
