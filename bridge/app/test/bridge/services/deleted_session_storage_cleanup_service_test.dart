import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/deleted_session_storage_cleanup_service.dart";
import "package:test/test.dart";

void main() {
  group("DeletedSessionStorageCleanupService", () {
    test("continues across tombstone reads and individual cleanup failures", () async {
      final repository = _FakeSessionRepository(
        cleanupPluginIds: ["cursor", "unavailable", "another"],
        tombstonesByPlugin: {
          "cursor": {"session-c", "session-a", "session-b"},
          "another": {"session-d"},
        },
        failingTombstoneReads: {"unavailable"},
        failingCleanups: {"cursor:session-b"},
      );
      final service = DeletedSessionStorageCleanupService(
        sessionRepository: repository,
      );

      await service.reconcile();

      expect(repository.cleanupCalls, [
        (pluginId: "cursor", backendSessionId: "session-a"),
        (pluginId: "cursor", backendSessionId: "session-b"),
        (pluginId: "cursor", backendSessionId: "session-c"),
        (pluginId: "another", backendSessionId: "session-d"),
      ]);
    });

    test("does nothing when no operational plugin supports cleanup", () async {
      final repository = _FakeSessionRepository(
        cleanupPluginIds: const [],
        tombstonesByPlugin: const {},
        failingTombstoneReads: const {},
        failingCleanups: const {},
      );
      final service = DeletedSessionStorageCleanupService(
        sessionRepository: repository,
      );

      await service.reconcile();

      expect(repository.cleanupCalls, isEmpty);
      expect(repository.tombstoneReadPluginIds, isEmpty);
    });
  });
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({
    required this.cleanupPluginIds,
    required this.tombstonesByPlugin,
    required this.failingTombstoneReads,
    required this.failingCleanups,
  });

  final List<String> cleanupPluginIds;
  final Map<String, Set<String>> tombstonesByPlugin;
  final Set<String> failingTombstoneReads;
  final Set<String> failingCleanups;
  final List<String> tombstoneReadPluginIds = [];
  final List<({String pluginId, String backendSessionId})> cleanupCalls = [];

  @override
  Future<List<String>> get persistedSessionCleanupPluginIds async => cleanupPluginIds;

  @override
  Future<Set<String>> getTombstonedBackendSessionIdsForCleanup({required String pluginId}) async {
    tombstoneReadPluginIds.add(pluginId);
    if (failingTombstoneReads.contains(pluginId)) {
      throw StateError("tombstone read failed");
    }
    return tombstonesByPlugin[pluginId] ?? const {};
  }

  @override
  Future<void> deletePersistedSession({
    required String pluginId,
    required String backendSessionId,
  }) async {
    cleanupCalls.add((
      pluginId: pluginId,
      backendSessionId: backendSessionId,
    ));
    if (failingCleanups.contains("$pluginId:$backendSessionId")) {
      throw StateError("cleanup failed");
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
