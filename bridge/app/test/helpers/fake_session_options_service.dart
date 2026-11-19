import "package:sesori_bridge/src/services/session_options_service.dart";

/// Records explicit refresh calls and otherwise no-ops, so prompt-service
/// tests can observe cache invalidation without a plugin runtime.
final class FakeSessionOptionsService() implements SessionOptionsService {
  final List<({String pluginId, String projectId})> explicitRefreshes = [];
  final List<({String pluginId, String projectId})> explicitInvalidations = [];
  SessionOptionsOutcome dynamicOutcome = const SessionOptionsAutomaticNoOp();
  SessionOptionsOutcome refreshOutcome = const SessionOptionsAutomaticNoOp();
  SessionOptionsOutcome cacheOutcome = const SessionOptionsAutomaticNoOp();

  @override
  Stream<SessionOptionsCacheUpdate> get cacheUpdates => const Stream<SessionOptionsCacheUpdate>.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> refreshActiveOnlyForCachedProjects({required String pluginId, required int generation}) async {}

  @override
  Future<SessionOptionsOutcome> loadDynamic({required String pluginId, required String projectId}) async =>
      dynamicOutcome;

  @override
  Future<SessionOptionsOutcome> loadCacheOnly({required String pluginId, required String projectId}) async =>
      cacheOutcome;

  @override
  Future<SessionOptionsOutcome> refreshExplicit({required String pluginId, required String projectId}) async {
    explicitRefreshes.add((pluginId: pluginId, projectId: projectId));
    return refreshOutcome;
  }

  @override
  Future<void> invalidateRejectedSelection({
    required String pluginId,
    required String projectId,
  }) async => explicitInvalidations.add((pluginId: pluginId, projectId: projectId));

  @override
  Future<SessionOptionsOutcome> refreshActiveOnly({
    required String pluginId,
    required String projectId,
    required int generation,
  }) async => const SessionOptionsAutomaticNoOp();

  @override
  Future<SessionOptionsOutcome> refreshActiveOnlyForBackendSession({
    required String pluginId,
    required String backendSessionId,
    required int generation,
  }) async => const SessionOptionsAutomaticNoOp();
}
