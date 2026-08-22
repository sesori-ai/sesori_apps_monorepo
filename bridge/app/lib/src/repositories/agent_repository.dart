import "dart:io" as io;

import "package:sesori_shared/sesori_shared.dart" show Agents, StringExtensions;

import "../api/database/daos/projects_dao.dart";
import "../api/plugin_runtime.dart";
import "mappers/plugin_agent_mapper.dart";
import "models/project_not_found_exception.dart";

class AgentRepository({
    required final PluginRuntime _runtime,
    required final ProjectsDao _projectsDao,
    required final String legacyPluginId,
  }) {

  Future<Agents> getAgents({required String? projectId, required String pluginId}) async {
    return await _runtime.use(
      pluginId: pluginId,
      operation: _AgentOperation.getAgents,
      body: (plugin) async {
        // A null/blank projectId comes from the deprecated GET /agent route,
        // which carries no project context. Fall back to the bridge CWD, which
        // plugins treat as the active project. A real id resolves to the
        // project's live directory — the plugin reads agents from disk there.
        final normalizedProjectId = projectId?.normalize();
        final String directory;
        if (normalizedProjectId == null) {
          directory = io.Directory.current.path;
        } else {
          final storedPath = await _projectsDao.getResolvedPath(projectId: normalizedProjectId);
          if (storedPath == null) {
            throw ProjectNotFoundException(projectId: normalizedProjectId);
          }
          directory = storedPath;
        }
        final pluginAgents = await plugin.getAgents(projectId: directory);
        final agents = pluginAgents.map((agent) => agent.toAgentInfo()).toList();
        return Agents(agents: agents);
      },
    );
  }
}

enum _AgentOperation() { getAgents }
