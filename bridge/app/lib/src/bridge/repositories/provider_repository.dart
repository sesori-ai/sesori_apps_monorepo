import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart" show ProviderListResponse;

import "../persistence/daos/projects_dao.dart";
import "mappers/plugin_provider_mapper.dart";
import "models/project_not_found_exception.dart";

/// Wraps [BridgePluginApi.getProviders] and maps plugin models to shared types.
class ProviderRepository {
  final BridgePluginApi _plugin;
  final ProjectsDao _projectsDao;

  ProviderRepository({required BridgePluginApi plugin, required ProjectsDao projectsDao})
    : _plugin = plugin,
      _projectsDao = projectsDao;

  Future<ProviderListResponse> getProviders({required String projectId, required String? pluginId}) async {
    _validatePluginSelection(pluginId: pluginId);
    // The plugin reads provider config from the project's directory, so
    // resolve the id to the live path first.
    final directory = await _projectsDao.getResolvedPath(projectId: projectId);
    if (directory == null) {
      throw ProjectNotFoundException(projectId: projectId);
    }
    final result = await _plugin.getProviders(projectId: directory);
    final providers = result.providers.map((p) => p.toSharedProviderInfo()).toList();
    return ProviderListResponse(items: providers, connectedOnly: true);
  }

  void _validatePluginSelection({required String? pluginId}) {
    if (pluginId == null || pluginId == _plugin.id) return;
    throw const PluginOperationException(
      "getProviders",
      statusCode: 400,
      message: "requested plugin is not active",
    );
  }
}
