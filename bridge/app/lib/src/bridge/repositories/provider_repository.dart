import "package:sesori_shared/sesori_shared.dart" show ProviderListResponse;

import "../../api/database/daos/projects_dao.dart";
import "../runtime/plugin_runtime.dart";
import "mappers/plugin_provider_mapper.dart";
import "models/project_not_found_exception.dart";

/// Wraps plugin provider reads and maps plugin models to shared types.
class ProviderRepository {
  final PluginRuntime _runtime;
  final ProjectsDao _projectsDao;

  ProviderRepository({required PluginRuntime runtime, required ProjectsDao projectsDao})
    : _runtime = runtime,
      _projectsDao = projectsDao;

  Future<ProviderListResponse> getProviders({required String projectId, required String pluginId}) async {
    return _runtime.use(
      pluginId: pluginId,
      operation: _ProviderOperation.getProviders,
      body: (plugin) async {
        // The plugin reads provider config from the project's directory.
        final directory = await _projectsDao.getResolvedPath(projectId: projectId);
        if (directory == null) {
          throw ProjectNotFoundException(projectId: projectId);
        }
        final result = await plugin.getProviders(projectId: directory);
        final providers = result.providers.map((provider) => provider.toSharedProviderInfo()).toList();
        return ProviderListResponse(items: providers, connectedOnly: true);
      },
    );
  }
}

enum _ProviderOperation { getProviders }
