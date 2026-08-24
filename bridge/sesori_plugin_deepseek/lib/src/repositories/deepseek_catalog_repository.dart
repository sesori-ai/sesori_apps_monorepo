import "package:acp_plugin/acp_plugin.dart" show AcpNewSessionResult, AcpStdioClient;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginSessionOptions;

import "../api/deepseek_acp_api.dart";
import "mappers/deepseek_catalog_mapper.dart";

class const DeepSeekCatalogRepository({
  required final DeepSeekAcpApi api,
  required final DeepSeekCatalogMapper mapper,
}) {
  Future<PluginSessionOptions> discover({
    required AcpStdioClient client,
    required String cwd,
    required Duration timeout,
  }) async => mapper.map(await api.catalog(client: client, cwd: cwd, timeout: timeout));

  ({String modelId, String providerId, String? variant})? mapSessionSelection(AcpNewSessionResult result) =>
      mapper.mapSessionSelection(result);
}
