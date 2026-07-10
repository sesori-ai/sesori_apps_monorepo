import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi;
import "package:sesori_shared/sesori_shared.dart" show Agents, StringExtensions;

import "../persistence/daos/projects_dao.dart";
import "mappers/plugin_agent_mapper.dart";
import "models/project_not_found_exception.dart";

class AgentRepository {
  final BridgePluginApi _plugin;
  final ProjectsDao _projectsDao;

  AgentRepository({required BridgePluginApi plugin, required ProjectsDao projectsDao})
    : _plugin = plugin,
      _projectsDao = projectsDao;

  Future<Agents> getAgents({required String? projectId}) async {
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
    final pluginAgents = await _plugin.getAgents(projectId: directory);
    final agents = pluginAgents.map((a) => a.toAgentInfo()).toList();
    return Agents(agents: agents);
  }
}
