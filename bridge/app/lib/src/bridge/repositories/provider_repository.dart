import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart" show ProviderListResponse;

import "../../api/database/daos/projects_dao.dart";
import "mappers/plugin_provider_mapper.dart";
import "models/project_not_found_exception.dart";

/// Wraps [BridgePluginApi.getProviders] and maps plugin models to shared types.
class ProviderRepository {
  final Map<String, BridgePluginApi> _operationalPlugins;
  final ProjectsDao _projectsDao;

  ProviderRepository({required Map<String, BridgePluginApi> operationalPlugins, required ProjectsDao projectsDao})
    : _operationalPlugins = operationalPlugins,
      _projectsDao = projectsDao;

  Future<ProviderListResponse> getProviders({required String projectId, required String pluginId}) async {
    final plugin = _operationalPlugins[pluginId];
    if (plugin == null) {
      throw PluginOperationException(
        "getProviders",
        statusCode: 503,
        message: "plugin $pluginId is not running",
      );
    }
    // The plugin reads provider config from the project's directory, so
    // resolve the id to the live path first.
    final directory = await _projectsDao.getResolvedPath(projectId: projectId);
    if (directory == null) {
      throw ProjectNotFoundException(projectId: projectId);
    }
    final result = await plugin.getProviders(projectId: directory);
    final providers = result.providers.map((p) => p.toSharedProviderInfo()).toList();
    return ProviderListResponse(items: providers, connectedOnly: true);
  }
}
