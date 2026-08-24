import "package:sesori_shared/sesori_shared.dart" show Agents, StringExtensions;

import "../api/database/daos/projects_dao.dart";
import "../runtime/plugin_runtime.dart";
import "mappers/plugin_agent_mapper.dart";
import "models/project_not_found_exception.dart";

class AgentRepository({
    required final PluginRuntime _runtime,
    required final ProjectsDao _projectsDao,
  }) {

  Future<Agents> getAgents({required String projectId, required String pluginId}) async {
    return await _runtime.use(
      pluginId: pluginId,
      operation: _AgentOperation.getAgents,
      body: (plugin) async {
        final normalizedProjectId = projectId.normalize();
        if (normalizedProjectId == null) {
          throw ProjectNotFoundException(projectId: projectId);
        }
        final storedPath = await _projectsDao.getResolvedPath(projectId: normalizedProjectId);
        if (storedPath == null) {
          throw ProjectNotFoundException(projectId: normalizedProjectId);
        }
        final pluginAgents = await plugin.getAgents(projectId: storedPath);
        final agents = pluginAgents.map((agent) => agent.toAgentInfo()).toList();
        return Agents(agents: agents);
      },
    );
  }
}

enum _AgentOperation() { getAgents }
