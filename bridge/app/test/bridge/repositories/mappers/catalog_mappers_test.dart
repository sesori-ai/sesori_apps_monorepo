import "package:sesori_bridge/src/bridge/persistence/tables/projects_table.dart";
import "package:sesori_bridge/src/bridge/persistence/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/project_catalog_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/session_catalog_mapper.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("ProjectCatalogMapper applies name precedence and maps catalog timestamps", () {
    const mapper = ProjectCatalogMapper();
    const base = ProjectDto(
      projectId: "project-1",
      path: "/projects/repository",
      displayName: null,
      createdAt: 10,
      updatedAt: 20,
      projectionUpdatedAt: 20,
    );

    expect(
      mapper.map(row: base, hasUnseenChanges: true, directoryMissing: false).name,
      "repository",
    );
    expect(
      mapper
          .map(
            row: base.copyWith(displayName: "Renamed"),
            hasUnseenChanges: false,
            directoryMissing: true,
          )
          .name,
      "Renamed",
    );
    expect(
      mapper
          .map(
            row: base,
            hasUnseenChanges: false,
            directoryMissing: false,
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
    expect(session.hasWorktree, isTrue);
    expect(session.unseen, isTrue);
  });
}
