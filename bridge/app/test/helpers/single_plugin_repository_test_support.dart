import "package:sesori_bridge/src/api/database/daos/catalog_hydrations_dao.dart";
import "package:sesori_bridge/src/api/database/daos/projects_dao.dart";
import "package:sesori_bridge/src/api/database/daos/pull_request_dao.dart";
import "package:sesori_bridge/src/api/database/daos/session_dao.dart";
import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/repositories/agent_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/permission_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/project_activity_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/provider_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/question_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/repositories/catalog_import_repository.dart";
import "package:sesori_bridge/src/repositories/project_catalog_identity_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "plugin_runtime_test_support.dart";

AgentRepository singlePluginAgentRepository({
  required BridgePluginApi plugin,
  required ProjectsDao projectsDao,
}) {
  return AgentRepository(
    runtime: createTestPluginRuntime(plugins: [plugin]),
    projectsDao: projectsDao,
    legacyPluginId: plugin.id,
  );
}

PermissionRepository singlePluginPermissionRepository({
  required BridgePluginApi plugin,
  required SessionDao sessionDao,
}) {
  return PermissionRepository(
    runtime: createTestPluginRuntime(plugins: [plugin]),
    sessionDao: sessionDao,
  );
}

ProjectRepository singlePluginProjectRepository({
  required ProjectsDao projectsDao,
  required SessionDao sessionDao,
  required SessionUnseenCalculator unseenCalculator,
  required FilesystemApi filesystemApi,
  required GitCliApi gitCliApi,
}) {
  return ProjectRepository(
    projectsDao: projectsDao,
    sessionDao: sessionDao,
    unseenCalculator: unseenCalculator,
    filesystemApi: filesystemApi,
    gitCliApi: gitCliApi,
    projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
  );
}

ProjectActivityRepository singlePluginProjectActivityRepository({
  required BridgePluginApi plugin,
  required ProjectsDao projectsDao,
  required SessionDao sessionDao,
}) {
  return ProjectActivityRepository(
    runtime: createTestPluginRuntime(plugins: [plugin]),
    projectsDao: projectsDao,
    sessionDao: sessionDao,
    projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
    aggregateSourceDeadline: const Duration(seconds: 5),
  );
}

ProviderRepository singlePluginProviderRepository({
  required BridgePluginApi plugin,
  required ProjectsDao projectsDao,
}) {
  return ProviderRepository(
    runtime: createTestPluginRuntime(plugins: [plugin]),
    projectsDao: projectsDao,
  );
}

QuestionRepository singlePluginQuestionRepository({
  required BridgePluginApi plugin,
  required SessionDao sessionDao,
  required ProjectsDao projectsDao,
}) {
  return QuestionRepository(
    runtime: createTestPluginRuntime(plugins: [plugin]),
    sessionDao: sessionDao,
    projectsDao: projectsDao,
    legacyMissingPluginId: plugin.id,
    aggregateSourceDeadline: const Duration(seconds: 5),
  );
}

SessionRepository singlePluginSessionRepository({
  required BridgePluginApi plugin,
  required SessionDao sessionDao,
  required ProjectsDao projectsDao,
  required PullRequestDao pullRequestDao,
  required SessionUnseenCalculator unseenCalculator,
  Set<String>? eligiblePluginIds,
}) {
  return SessionRepository(
    runtime: createTestPluginRuntime(
      plugins: [plugin],
      eligiblePluginIds: eligiblePluginIds,
    ),
    bridgeDerivedProjectPluginIds: {
      if (plugin is BridgeDerivedProjectsPluginApi) plugin.id,
    },
    sessionDao: sessionDao,
    projectsDao: projectsDao,
    pullRequestDao: pullRequestDao,
    unseenCalculator: unseenCalculator,
    projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
    aggregateSourceDeadline: const Duration(seconds: 5),
  );
}

WorktreeRepository singlePluginWorktreeRepository({
  required ProjectsDao projectsDao,
  required SessionDao sessionDao,
  required GitCliApi gitApi,
  required BridgePluginApi plugin,
}) {
  return WorktreeRepository(
    projectsDao: projectsDao,
    sessionDao: sessionDao,
    gitApi: gitApi,
    runtime: createTestPluginRuntime(plugins: [plugin]),
  );
}

CatalogImportRepository singlePluginCatalogImportRepository({
  required BridgePluginApi plugin,
  required ProjectsDao projectsDao,
  required SessionDao sessionDao,
  required CatalogHydrationsDao catalogHydrationsDao,
}) {
  return CatalogImportRepository(
    runtime: createTestPluginRuntime(plugins: [plugin]),
    projectsDao: projectsDao,
    sessionDao: sessionDao,
    catalogHydrationsDao: catalogHydrationsDao,
    projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
  );
}
