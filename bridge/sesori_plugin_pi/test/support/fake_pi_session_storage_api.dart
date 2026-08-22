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
  int resolveCalls = 0;

  Future<List<PiSessionMetadata>> list() async {
    await listGate?.future;
    if (listError case final error?) throw error;
    return sessions;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class FakePiCatalogSessionStorageApi({
  super.initialSessions,
  super.listGate,
  super.listError,
}) extends FakePiSessionStorageApi {
  @override
  Future<List<PiSessionMetadata>> listSessionMetadata({required Set<String> knownDirectories}) {
    listedKnownDirectories.add(Set.unmodifiable(knownDirectories));
    return list();
  }

  @override
  Future<String?> resolveEffectiveSessionDirectory({required String directory}) async => null;

  @override
  Future<PiResolvedSession?> resolveSession({required String sessionId, required Set<String> knownDirectories}) async =>
      null;

  @override
  Future<String?> resolveSessionPath({required String sessionId, required Set<String> knownDirectories}) async => null;
}

final class FakePiExtensionSessionStorageApi({
  super.initialSessions,
  super.listGate,
  super.listError,
}) extends FakePiSessionStorageApi {
  @override
  Future<List<PiSessionMetadata>> listSessionMetadata({required Set<String> knownDirectories}) => list();

  @override
  Future<String?> resolveEffectiveSessionDirectory({required String directory}) async => null;

  @override
  Future<PiResolvedSession?> resolveSession({required String sessionId, required Set<String> knownDirectories}) async {
    for (final metadata in sessions) {
      if (metadata.id == sessionId) {
        return PiResolvedSession(metadata: metadata, path: "/sessions/$sessionId.jsonl");
      }
    }
    return null;
  }

  @override
  Future<String?> resolveSessionPath({required String sessionId, required Set<String> knownDirectories}) async => null;

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
  Future<PiResolvedSession?> resolveSession({required String sessionId, required Set<String> knownDirectories}) async {
    resolveCalls++;
    return resolvedSession;
  }

  @override
  Future<String?> resolveSessionPath({required String sessionId, required Set<String> knownDirectories}) async =>
      (await resolveSession(sessionId: sessionId, knownDirectories: knownDirectories))?.path;

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
  Future<List<PiSessionMetadata>> listSessionMetadata({required Set<String> knownDirectories}) async => sessions;
}
