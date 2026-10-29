import "dart:async";

import "package:pi_plugin/pi_plugin.dart";

class FakePiSessionStorageApi({
  final List<PiSessionMetadata> initialSessions = const [],
  final PiResolvedSession? initialResolvedSession,
  final PiPendingNewSession? initialPendingNewSession,
  final Completer<void>? listGate,
  final Object? listError,
  final Object? clearError,
}) implements PiSessionStorageApi {
  late List<PiSessionMetadata> sessions = initialSessions;
  late PiResolvedSession? resolvedSession = initialResolvedSession;
  late PiPendingNewSession? pendingNewSession = initialPendingNewSession;
  final List<Set<String>> listedKnownDirectories = [];
  Set<String>? clearedKnownDirectories;
  int scanCalls = 0;

  Future<List<PiSessionMetadata>> list() async {
    await listGate?.future;
    if (listError case final error?) throw error;
    return sessions;
  }

  /// The persisted sessions a scan reports, each at `/sessions/<id>.jsonl`.
  Future<List<PiResolvedSession>> scannedSessions({required Set<String> knownDirectories}) async => [
    for (final metadata in await list()) PiResolvedSession(metadata: metadata, path: fakeSessionPath(metadata.id)),
  ];

  /// Reports every session as a new file, so each scan replaces the catalog.
  @override
  Future<PiSessionFileScan> scanSessionFiles({
    required Set<String> knownDirectories,
    required Map<String, PiKnownSessionFile> known,
  }) async {
    scanCalls++;
    listedKnownDirectories.add(Set.unmodifiable(knownDirectories));
    final parsed = {
      for (final PiResolvedSession(:metadata, :path) in await scannedSessions(knownDirectories: knownDirectories))
        path: PiScannedSessionFile(
          stamp: (size: 0, modified: metadata.updatedAt),
          session: PiSessionFile(
            path: path,
            id: metadata.id,
            cwd: metadata.cwd,
            parentPath: switch (metadata.parentId) {
              final parentId? => fakeSessionPath(parentId),
              null => null,
            },
            title: metadata.title,
            createdAt: metadata.createdAt,
            updatedAt: metadata.updatedAt,
          ),
        ),
    };
    return PiSessionFileScan(present: parsed.keys.toSet(), parsed: parsed, externalParents: const []);
  }

  @override
  List<PiResolvedSession> linkSessionFiles({required Iterable<PiSessionFile> files}) =>
      PiSessionStorageApi(environment: const {}).linkSessionFiles(files: files);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String fakeSessionPath(String sessionId) => "/sessions/$sessionId.jsonl";

final class FakePiCatalogSessionStorageApi({
  super.initialSessions,
  super.listGate,
  super.listError,
}) extends FakePiSessionStorageApi {
  @override
  Future<String?> resolveEffectiveSessionDirectory({required String directory}) async => null;
}

final class FakePiExtensionSessionStorageApi({
  super.initialSessions,
  super.listGate,
  super.listError,
}) extends FakePiSessionStorageApi {
  @override
  Future<String?> resolveEffectiveSessionDirectory({required String directory}) async => null;

  @override
  Future<PiPendingNewSession?> readPendingNewSession({
    required String sessionId,
    required Set<String> knownDirectories,
  }) async => null;

  @override
  Future<void> clearPendingNewSession({required String sessionId, required Set<String> knownDirectories}) async {}

  @override
  Future<void> writePendingNewSession({
    required String sessionId,
    required String cwd,
    required String? parentSessionPath,
  }) async {}
}

class FakePiServiceSessionStorageApi({
  required super.initialResolvedSession,
  super.initialPendingNewSession,
  super.clearError,
}) extends FakePiSessionStorageApi {
  @override
  Future<List<PiResolvedSession>> scannedSessions({required Set<String> knownDirectories}) async => [
    ?resolvedSession,
  ];

  @override
  Future<PiPendingNewSession?> readPendingNewSession({
    required String sessionId,
    required Set<String> knownDirectories,
  }) async => pendingNewSession;

  @override
  Future<void> clearPendingNewSession({required String sessionId, required Set<String> knownDirectories}) async {
    if (clearError case final error?) throw error;
    clearedKnownDirectories = Set.of(knownDirectories);
    pendingNewSession = null;
  }

  @override
  Future<void> writePendingNewSession({
    required String sessionId,
    required String cwd,
    required String? parentSessionPath,
  }) async {
    pendingNewSession = PiPendingNewSession(id: sessionId, cwd: cwd, parentSessionPath: parentSessionPath);
  }

  @override
  void deleteSessionFile({required String path}) {
    if (resolvedSession?.path == path) resolvedSession = null;
  }
}
