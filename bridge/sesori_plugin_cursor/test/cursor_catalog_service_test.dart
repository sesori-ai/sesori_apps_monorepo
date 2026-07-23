import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:cursor_plugin/src/models/cursor_catalog_models.dart";
import "package:cursor_plugin/src/repositories/cursor_catalog_repository.dart";
import "package:cursor_plugin/src/services/cursor_catalog_service.dart";
import "package:cursor_plugin/src/trackers/cursor_catalog_tracker.dart";
import "package:test/test.dart";

void main() {
  group("CursorCatalogService", () {
    late _FakeCursorCatalogRepository repository;
    late CursorCatalogTracker tracker;
    late CursorCatalogService service;

    setUp(() {
      repository = _FakeCursorCatalogRepository();
      tracker = CursorCatalogTracker();
      service = CursorCatalogService(
        repository: repository,
        tracker: tracker,
        totalTimeout: const Duration(seconds: 12),
        maxCandidates: 8,
      );
      addTearDown(service.dispose);
    });

    test("loads candidates most-recent-first and stops when complete", () async {
      repository.candidates = _candidates([
        (id: "old", updatedAtMs: 100),
        (id: "new", updatedAtMs: 300),
        (id: "middle", updatedAtMs: 200),
      ]);
      repository.snapshots["new"] = _snapshot(includeThoughtLevel: false);
      repository.snapshots["middle"] = _snapshot(includeThoughtLevel: true);

      await service.ensureCatalog(scope: "/project");

      expect(repository.loadedSessionIds, ["new", "middle"]);
      expect(tracker.isComplete, isTrue);
      expect(
        tracker.outcomeForScope(scope: "/project"),
        CursorCatalogProbeOutcome.complete,
      );
      expect(repository.resetCount, 1, reason: "the dedicated probe process is short-lived");
    });

    test("uses the account catalog when no existing session is available", () async {
      repository.bootstrapSnapshot = CursorCatalogBootstrapSnapshot(
        models: const [
          CursorCatalogOption(value: "default", name: "Auto", description: null),
          CursorCatalogOption(value: "gpt-5.6-sol", name: "GPT-5.6 Sol", description: null),
        ],
        modes: const [
          CursorCatalogOption(value: "agent", name: "Agent", description: null),
          CursorCatalogOption(value: "plan", name: "Plan", description: null),
          CursorCatalogOption(value: "ask", name: "Ask", description: null),
        ],
        defaultModeId: "agent",
        thoughtLevelsByModel: {
          "gpt-5.6-sol": CursorThoughtLevelSnapshot(
            configId: "reasoning",
            variants: const ["medium", "none", "low", "high"],
            defaultValue: "medium",
          ),
        },
      );

      await service.ensureCatalog(scope: "/project");

      expect(tracker.isComplete, isTrue);
      expect(tracker.models.map((model) => model.value), ["default", "gpt-5.6-sol"]);
      expect(tracker.modes.map((mode) => mode.value), ["agent", "plan", "ask"]);
      expect(tracker.variantsForModel(modelId: "gpt-5.6-sol"), ["medium", "none", "low", "high"]);
      expect(repository.listedScopes, isEmpty, reason: "no historical session walk is needed");
      expect(
        tracker.outcomeForScope(scope: "/project"),
        CursorCatalogProbeOutcome.complete,
      );
    });

    test("falls back to existing sessions when account catalog discovery fails", () async {
      repository.bootstrapError = StateError("extension unavailable");
      repository.candidates = _candidates([(id: "session", updatedAtMs: 1)]);
      repository.snapshots["session"] = _snapshot(includeThoughtLevel: true);

      await service.ensureCatalog(scope: "/project");

      expect(repository.loadedSessionIds, ["session"]);
      expect(tracker.isComplete, isTrue);
    });

    test("loads at most eight candidates", () async {
      repository.candidates = _candidates([
        for (var i = 0; i < 10; i++) (id: "s$i", updatedAtMs: i),
      ]);

      await service.ensureCatalog(scope: "/project");

      expect(repository.loadedSessionIds, hasLength(8));
      expect(repository.loadedSessionIds.first, "s9");
      expect(repository.loadedSessionIds.last, "s2");
      expect(
        tracker.outcomeForScope(scope: "/project"),
        CursorCatalogProbeOutcome.exhausted,
      );
      expect(repository.resetCount, 1, reason: "the dedicated probe process is short-lived");
    });

    test("continues after a failed load and records a retryable outcome", () async {
      repository.candidates = _candidates([
        (id: "failed", updatedAtMs: 200),
        (id: "partial", updatedAtMs: 100),
      ]);
      repository.loadErrors["failed"] = StateError("cannot load");
      repository.snapshots["partial"] = _snapshot(includeThoughtLevel: false);

      await service.ensureCatalog(scope: "/project");

      expect(repository.loadedSessionIds, ["failed", "partial"]);
      expect(
        tracker.outcomeForScope(scope: "/project"),
        CursorCatalogProbeOutcome.retryableFailure,
      );
      expect(repository.resetCount, 1);
    });

    test("retries a failed scope once on the next request", () async {
      repository.candidates = CursorCatalogCandidateListResult(
        candidates: const [],
        exhaustive: false,
      );

      await service.ensureCatalog(scope: "/project");
      await service.ensureCatalog(scope: "/project");
      await service.ensureCatalog(scope: "/project");

      expect(repository.listedScopes, ["/project", "/project"]);
      expect(repository.resetCount, 2);
      expect(
        tracker.outcomeForScope(scope: "/project"),
        CursorCatalogProbeOutcome.retryableFailure,
      );
    });

    test("does not repeat an exhausted scope", () async {
      repository.candidates = CursorCatalogCandidateListResult(
        candidates: const [],
        exhaustive: true,
      );

      await service.ensureCatalog(scope: "/project");
      await service.ensureCatalog(scope: "/project");

      expect(repository.listedScopes, ["/project"]);
      expect(
        tracker.outcomeForScope(scope: "/project"),
        CursorCatalogProbeOutcome.exhausted,
      );
    });

    test("an exhausted launch scope does not suppress another project scope", () async {
      repository.candidates = CursorCatalogCandidateListResult(
        candidates: const [],
        exhaustive: true,
      );

      await service.ensureCatalog(scope: "/launch");
      await service.ensureCatalog(scope: "/project");

      expect(repository.listedScopes, ["/launch", "/project"]);
    });

    test("waiting callers recheck and probe their own scope", () async {
      repository.candidates = CursorCatalogCandidateListResult(
        candidates: const [],
        exhaustive: true,
      );
      repository.listGate = Completer<void>();

      final launch = service.ensureCatalog(scope: "/launch");
      final project = service.ensureCatalog(scope: "/project");
      await Future<void>.delayed(Duration.zero);
      repository.listGate!.complete();
      await Future.wait([launch, project]);

      expect(repository.listedScopes, ["/launch", "/project"]);
      expect(repository.maxConcurrentLists, 1);
    });

    test("waiting callers share the one retry for a failed scope", () async {
      repository.candidates = CursorCatalogCandidateListResult(
        candidates: const [],
        exhaustive: false,
      );
      repository.listGate = Completer<void>();

      final first = service.ensureCatalog(scope: "/project");
      final second = service.ensureCatalog(scope: "/project");
      final third = service.ensureCatalog(scope: "/project");
      await Future<void>.delayed(Duration.zero);
      repository.listGate!.complete();
      await Future.wait([first, second, third]);
      await service.ensureCatalog(scope: "/project");

      expect(repository.listedScopes, ["/project", "/project"]);
      expect(repository.maxConcurrentLists, 1);
      expect(repository.resetCount, 2);
    });

    test("short deadline completes and resets a timed-out repository", () async {
      service = CursorCatalogService(
        repository: repository,
        tracker: tracker,
        totalTimeout: const Duration(milliseconds: 20),
        maxCandidates: 8,
      );
      repository.candidates = _candidates([(id: "slow", updatedAtMs: 1)]);
      repository.delayLoadsUntilTimeout = true;
      final stopwatch = Stopwatch()..start();

      await service.ensureCatalog(scope: "/project");

      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 500)));
      expect(
        tracker.outcomeForScope(scope: "/project"),
        CursorCatalogProbeOutcome.retryableFailure,
      );
      expect(repository.resetCount, 1);
    });
  });
}

CursorCatalogCandidateListResult _candidates(
  List<({String id, int updatedAtMs})> sessions,
) {
  return CursorCatalogCandidateListResult(
    candidates: [
      for (final session in sessions)
        CursorCatalogCandidate(
          sessionId: session.id,
          cwd: "/project",
          updatedAtMs: session.updatedAtMs,
        ),
    ],
    exhaustive: true,
  );
}

CursorCatalogSnapshot _snapshot({required bool includeThoughtLevel}) {
  return CursorCatalogSnapshot(
    modelConfigId: "model-picker",
    models: const [
      CursorCatalogOption(value: "gpt-5.4", name: "GPT-5.4", description: null),
    ],
    loadedModelId: "gpt-5.4",
    modeConfigId: "mode-picker",
    modes: const [
      CursorCatalogOption(value: "agent", name: "Agent", description: null),
    ],
    loadedModeId: "agent",
    thoughtLevel: includeThoughtLevel
        ? CursorThoughtLevelSnapshot(
            configId: "effort",
            variants: const ["medium", "low", "high"],
            defaultValue: "medium",
          )
        : null,
  );
}

class _FakeCursorCatalogRepository implements CursorCatalogRepository {
  CursorCatalogCandidateListResult candidates = CursorCatalogCandidateListResult(
    candidates: const [],
    exhaustive: true,
  );
  final Map<String, CursorCatalogSnapshot> snapshots = {};
  final Map<String, Object> loadErrors = {};
  final List<String> loadedSessionIds = [];
  final List<String> listedScopes = [];
  Completer<void>? listGate;
  bool probeSupported = true;
  bool delayLoadsUntilTimeout = false;
  CursorCatalogBootstrapSnapshot? bootstrapSnapshot;
  Object? bootstrapError;
  int resetCount = 0;
  int _concurrentLists = 0;
  int maxConcurrentLists = 0;

  @override
  Future<bool> open({required Duration timeout}) async => probeSupported;

  @override
  Future<CursorCatalogBootstrapSnapshot?> loadAvailableCatalog({required Duration timeout}) async {
    final error = bootstrapError;
    if (error != null) throw error;
    return bootstrapSnapshot;
  }

  @override
  Future<CursorCatalogCandidateListResult> listCandidates({
    required String scope,
    required Duration timeout,
  }) async {
    listedScopes.add(scope);
    _concurrentLists++;
    if (_concurrentLists > maxConcurrentLists) maxConcurrentLists = _concurrentLists;
    try {
      await listGate?.future;
      return candidates;
    } finally {
      _concurrentLists--;
    }
  }

  @override
  Future<CursorCatalogSnapshot> loadCandidate({
    required CursorCatalogCandidate candidate,
    required Duration timeout,
  }) async {
    loadedSessionIds.add(candidate.sessionId);
    if (delayLoadsUntilTimeout) {
      await Future<void>.delayed(timeout);
      throw TimeoutException("catalog load timed out");
    }
    final error = loadErrors[candidate.sessionId];
    if (error != null) throw error;
    return snapshots[candidate.sessionId] ?? _snapshot(includeThoughtLevel: false);
  }

  @override
  CursorCatalogSnapshot mapSessionResult({required AcpNewSessionResult result}) {
    throw UnimplementedError();
  }

  @override
  Future<void> reset() async {
    resetCount++;
  }

  @override
  Future<void> dispose() async {}
}
