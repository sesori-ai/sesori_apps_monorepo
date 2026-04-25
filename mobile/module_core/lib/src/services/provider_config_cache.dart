import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

/// In-memory cache for provider config, keyed by projectId.
///
/// Cleared when user navigates away from project context.
@lazySingleton
class ProviderConfigCache {
  final _cache = <String, ProviderListResponse>{};

  ProviderListResponse? get({required String projectId}) => _cache[projectId];

  void set({
    required String projectId,
    required ProviderListResponse response,
  }) {
    _cache[projectId] = response;
  }

  void clear() => _cache.clear();

  bool has({required String projectId}) => _cache.containsKey(projectId);
}
