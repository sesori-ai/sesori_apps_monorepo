import "package:sesori_bridge/src/api/database/tables/projects_table.dart";
import "package:sesori_bridge/src/api/database/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/project_catalog_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/session_catalog_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/stored_session_mapper.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("ProjectCatalogMapper maps durable summary fields", () {
    const mapper = ProjectCatalogMapper();
    const base = ProjectDto(
      projectId: "project-1",
      path: "/projects/repository",
      displayName: null,
      prCacheGithubLogin: null,
      createdAt: 10,
      updatedAt: 20,
      projectionUpdatedAt: 20,
    );

    expect(
      mapper.mapSummary(row: base, hasUnseenChanges: true),
      const ProjectSummary(
        id: "project-1",
        name: "repository",
        path: "/projects/repository",
        time: ProjectTime(created: 10, updated: 20),
        hasUnseenChanges: true,
      ),
    );
    expect(
      mapper.mapSummary(row: base.copyWith(displayName: "Renamed"), hasUnseenChanges: false).name,
      "Renamed",
    );
  });

  test("ProjectCatalogMapper maps selected-project capabilities", () {
    const mapper = ProjectCatalogMapper();
    const base = ProjectDto(
      projectId: "project-1",
      path: "/projects/repository",
      displayName: null,
      prCacheGithubLogin: null,
      createdAt: 10,
      updatedAt: 20,
      projectionUpdatedAt: 20,
    );

    expect(
      mapper
          .mapProject(
            row: base,
            hasUnseenChanges: false,
            directoryMissing: false,
            supportsDedicatedWorktrees: true,
          )
          .name,
      "repository",
    );
  });

  test("SessionCatalogMapper maps stable identity and projection metadata", () {
    const mapper = SessionCatalogMapper();
    const row = SessionDto(
      sessionId: "sesori-id",
      backendSessionId: "backend-id",
      projectId: "project-1",
      parentSessionId: "parent-id",
      directory: "/projects/one",
      worktreePath: "/worktrees/one",
      branchName: "feature",
      currentBranchName: "current-feature",
      currentGithubRepositoryIdentity: "sesori-ai/sesori_apps_monorepo",
      isDedicated: true,
      archivedAt: null,
      baseBranch: "main",
      baseCommit: "abc",
      lastAgent: "build",
      lastAgentModel: AgentModel(providerID: "anthropic", modelID: "claude", variant: null),
      createdAt: 10,
      updatedAt: 20,
      projectionUpdatedAt: 20,
      lastActivityAt: 20,
      lastSeenAt: 15,
      lastUserMessageAt: 12,
      pluginId: "codex",
      title: null,
      catalogTitle: "Observed title",
    );

    final session = mapper.map(row: row, pullRequest: null, unseen: true);

    expect(session.id, "sesori-id");
    expect(session.pluginId, "codex");
    expect(session.parentID, "parent-id");
    expect(session.title, "Observed title");
    expect(session.promptDefaults?.agent, "build");
    expect(session.branchName, "current-feature");
    expect(session.hasWorktree, isTrue);
    expect(session.unseen, isTrue);
    expect(session.lastUserActivityAt, 12);
  });

  test("StoredSessionMapper projects the fields repository consumers need", () {
    const row = SessionDto(
      sessionId: "sesori-id",
      backendSessionId: "backend-id",
      projectId: "project-1",
      parentSessionId: "parent-id",
      directory: "/projects/one",
      worktreePath: "/worktrees/one",
      branchName: "feature",
      currentBranchName: "current-feature",
      currentGithubRepositoryIdentity: "sesori-ai/sesori_apps_monorepo",
      isDedicated: true,
      archivedAt: 30,
      baseBranch: "main",
      baseCommit: "abc",
      lastAgent: "build",
      lastAgentModel: AgentModel(providerID: "anthropic", modelID: "claude", variant: "high"),
      createdAt: 10,
      updatedAt: 20,
      projectionUpdatedAt: 21,
      lastActivityAt: 22,
      lastSeenAt: 23,
      lastUserMessageAt: 24,
      pluginId: "codex",
      title: "Override",
      catalogTitle: "Observed",
    );

    final stored = row.toStoredSession();

    expect(stored.id, row.sessionId);
    expect(stored.backendSessionId, row.backendSessionId);
    expect(stored.pluginId, row.pluginId);
    expect(stored.projectId, row.projectId);
    expect(stored.directory, row.directory);
    expect(stored.worktreePath, row.worktreePath);
    expect(stored.branchName, row.branchName);
    expect(stored.isDedicated, row.isDedicated);
    expect(stored.archivedAt, row.archivedAt);
    expect(stored.baseBranch, row.baseBranch);
    expect(stored.baseCommit, row.baseCommit);
  });
}
