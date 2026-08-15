import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/deleted_session_storage_cleanup_service.dart";
import "package:test/test.dart";

void main() {
  group("DeletedSessionStorageCleanupService", () {
    test("continues across tombstone reads and individual cleanup failures", () async {
      final repository = _FakeSessionRepository(
        cleanupPluginIds: ["cursor", "unavailable", "another"],
        tombstonesByPlugin: {
          "cursor": {
            (backendSessionId: "session-c", directory: "/repo-c"),
            (backendSessionId: "session-a", directory: null),
            (backendSessionId: "session-b", directory: "/repo-b"),
          },
          "another": {(backendSessionId: "session-d", directory: "/repo-d")},
        },
        failingTombstoneReads: {"unavailable"},
        failingCleanups: {"cursor:session-b"},
      );
      final service = DeletedSessionStorageCleanupService(
        sessionRepository: repository,
      );

      await service.reconcile();

      expect(repository.cleanupCalls, [
        (pluginId: "cursor", backendSessionId: "session-a", directory: null),
        (pluginId: "cursor", backendSessionId: "session-b", directory: "/repo-b"),
        (pluginId: "cursor", backendSessionId: "session-c", directory: "/repo-c"),
        (pluginId: "another", backendSessionId: "session-d", directory: "/repo-d"),
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

class _FakeSessionRepository({
  required final List<String> cleanupPluginIds,
  required final Map<String, Set<TombstonedSessionCleanup>> tombstonesByPlugin,
  required final Set<String> failingTombstoneReads,
  required final Set<String> failingCleanups,
}) implements SessionRepository {
  final List<String> tombstoneReadPluginIds = [];
  final List<({String pluginId, String backendSessionId, String? directory})> cleanupCalls = [];

  @override
  Future<List<String>> get persistedSessionCleanupPluginIds async => cleanupPluginIds;

  @override
  Future<Set<TombstonedSessionCleanup>> getTombstonedSessionsForCleanup({required String pluginId}) async {
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
    required String? directory,
  }) async {
    cleanupCalls.add((
      pluginId: pluginId,
      backendSessionId: backendSessionId,
      directory: directory,
    ));
    if (failingCleanups.contains("$pluginId:$backendSessionId")) {
      throw StateError("cleanup failed");
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
