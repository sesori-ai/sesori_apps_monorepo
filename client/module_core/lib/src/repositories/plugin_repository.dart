import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/plugin_api.dart";

@lazySingleton
class PluginRepository {
  final PluginApi _api;

  PluginRepository({required PluginApi api}) : _api = api;

  Future<ApiResponse<PluginListResponse>> listPlugins() => _api.listPlugins();
}
