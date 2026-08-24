import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/repositories/models/catalog_import_result.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_management_result.dart";
import "package:sesori_dart_core/src/repositories/plugin_repository.dart";
import "package:sesori_dart_core/src/services/catalog_rescan_service.dart";
import "package:sesori_dart_core/src/services/models/catalog_rescan_state.dart";
import "package:sesori_dart_core/src/services/plugin_management_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("CatalogRescanService", () {
    late _FakePluginRepository repository;
    late _FakeConnectionService connection;
    late _FakeManagementService management;
    late CatalogRescanService service;

    void build({
      PluginManagementLoadResult? snapshot,
      ConnectionStatus initialStatus = _connected,
    }) {
      repository = _FakePluginRepository();
      connection = _FakeConnectionService(initialStatus: initialStatus);
      management = _FakeManagementService(
        snapshot ?? _snapshot(routable: const {"codex": "Codex", "claude": "Claude"}),
      );
      service = CatalogRescanService(
        pluginRepository: repository,
        managementService: management,
        connectionService: connection,
      );
    }

    setUp(build);

    tearDown(() async {
      await service.onDispose();
      await connection.dispose();
      await management.dispose();
    });

    test("starts idle and fans out one request per routable harness", () async {
      expect(service.state.value, isA<CatalogRescanIdle>());

      await service.startAll();

      expect(repository.startedPluginIds, unorderedEquals(["codex", "claude"]));
      expect(
        service.state.value,
        isA<CatalogRescanStarting>().having((s) => s.pluginIds, "pluginIds", {"codex", "claude"}),
      );
    });

    test("names the enumerating harness once progress arrives", () async {
      await service.startAll();

      connection.emitProgress(const CatalogImportProgress.enumerating(
        pluginId: "codex",
        projectsSeen: 3,
        sessionsSeen: 42,
      ));

      expect(
        service.state.value,
        isA<CatalogRescanRunning>()
            .having((s) => s.activePluginName, "activePluginName", "Codex")
            .having((s) => s.sessionsSeen, "sessionsSeen", 42),
      );
    });

    test("sums deltas across every harness rather than reporting the last one", () async {
      await service.startAll();

      connection.emitProgress(_completed("codex", newProjects: 2, newSessions: 5));
      connection.emitProgress(_completed("claude", newProjects: 1, newSessions: 3));

      expect(
        service.state.value,
        isA<CatalogRescanSucceeded>()
            .having((s) => s.harnessCount, "harnessCount", 2)
            .having(
              (s) => s.counts,
              "counts",
              isA<CatalogRescanDelta>()
                  .having((c) => c.newProjects, "newProjects", 3)
                  .having((c) => c.newSessions, "newSessions", 8),
            ),
      );
    });

    test("falls back to summed totals when any harness omits its delta", () async {
      await service.startAll();

      connection.emitProgress(_completed("codex", newProjects: 2, newSessions: 5, totals: 10));
      // An older bridge omits newItems entirely.
      connection.emitProgress(_completed("claude", totals: 7));

      expect(
        service.state.value,
        isA<CatalogRescanSucceeded>().having(
          (s) => s.counts,
          "counts",
          isA<CatalogRescanTotals>()
              .having((c) => c.projects, "projects", 17)
              .having((c) => c.sessions, "sessions", 17),
        ),
      );
    });

    test("reports a mixed outcome when one harness fails", () async {
      await service.startAll();

      connection.emitProgress(_completed("codex", newProjects: 1, newSessions: 1));
      connection.emitProgress(const CatalogImportProgress.failed(
        pluginId: "claude",
        message: "boom: /Users/someone/secret/path",
      ));

      expect(
        service.state.value,
        isA<CatalogRescanPartlyFailed>()
            .having((s) => s.succeededCount, "succeededCount", 1)
            .having((s) => s.failedCount, "failedCount", 1),
      );
    });

    test("reports total failure when every harness fails, carrying no bridge text", () async {
      await service.startAll();

      connection.emitProgress(const CatalogImportProgress.failed(pluginId: "codex", message: "a"));
      connection.emitProgress(const CatalogImportProgress.failed(pluginId: "claude", message: "b"));

      final state = service.state.value;
      expect(state, isA<CatalogRescanFailed>().having((s) => s.harnessCount, "harnessCount", 2));
      expect(state.toString(), isNot(contains("boom")));
    });

    test("clears a success after its window but keeps a failure until dismissed", () async {
      fakeAsync((async) {
        // Rebuilt inside the zone: a stream listener runs in the zone that
        // called listen, so a service built in setUp would schedule real
        // timers that elapse cannot advance.
        build();
        unawaited(service.startAll());
        async.flushMicrotasks();
        connection.emitProgress(_completed("codex", newProjects: 1, newSessions: 1));
        connection.emitProgress(_completed("claude", newProjects: 0, newSessions: 0));
        expect(service.state.value, isA<CatalogRescanSucceeded>());

        async.elapse(const Duration(seconds: 5));
        expect(service.state.value, isA<CatalogRescanIdle>());

        unawaited(service.startAll());
        async.flushMicrotasks();
        connection.emitProgress(const CatalogImportProgress.failed(pluginId: "codex", message: "x"));
        connection.emitProgress(const CatalogImportProgress.failed(pluginId: "claude", message: "y"));
        expect(service.state.value, isA<CatalogRescanFailed>());

        async.elapse(const Duration(seconds: 30));
        expect(service.state.value, isA<CatalogRescanFailed>(), reason: "a failure must be read");

        service.dismiss();
        expect(service.state.value, isA<CatalogRescanIdle>());
      });
    });

    test("a second rescan inside the success window is not reset by the stale timer", () async {
      fakeAsync((async) {
        build();
        unawaited(service.startAll());
        async.flushMicrotasks();
        connection.emitProgress(_completed("codex", newProjects: 1, newSessions: 1));
        connection.emitProgress(_completed("claude", newProjects: 1, newSessions: 1));
        expect(service.state.value, isA<CatalogRescanSucceeded>());

        async.elapse(const Duration(seconds: 1));
        unawaited(service.startAll());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));

        expect(
          service.state.value,
          isA<CatalogRescanStarting>(),
          reason: "the previous success timer must not reset the new run",
        );
      });
    });

    test("a second sequential rescan does not inherit the previous aggregate", () async {
      await service.startAll();
      connection.emitProgress(_completed("codex", newProjects: 9, newSessions: 9));
      connection.emitProgress(_completed("claude", newProjects: 9, newSessions: 9));
      expect(service.state.value, isA<CatalogRescanSucceeded>());
      service.dismiss();

      await service.startAll();

      expect(
        service.state.value,
        isA<CatalogRescanStarting>(),
        reason: "retained progress from the previous run must be cleared",
      );
      connection.emitProgress(_completed("codex", newProjects: 0, newSessions: 0));
      expect(service.state.value, isA<CatalogRescanStarting>(), reason: "claude has not settled");
    });

    test("a targeted start joins the live operation instead of replacing it", () async {
      build(snapshot: _snapshot(routable: const {"codex": "Codex"}));
      await service.startAll();
      expect((service.state.value as CatalogRescanStarting).pluginIds, {"codex"});

      final result = await service.start(pluginId: "claude");

      expect(result, isA<CatalogRescanStartAccepted>());
      expect(
        (service.state.value as CatalogRescanStarting).pluginIds,
        {"codex", "claude"},
        reason: "codex must stay in aggregation and cancellation",
      );
    });

    test("skips a harness the bridge reports unavailable, without failing the run", () async {
      repository.resultFor["claude"] = const CatalogImportMutationResult.unavailable();

      await service.startAll();

      expect((service.state.value as CatalogRescanStarting).pluginIds, {"codex"});
      connection.emitProgress(_completed("codex", newProjects: 1, newSessions: 0));
      expect(
        service.state.value,
        isA<CatalogRescanSucceeded>().having((s) => s.harnessCount, "harnessCount", 1),
      );
    });

    test("keeps a harness whose response was lost, so SSE still settles it", () async {
      repository.resultFor["claude"] = CatalogImportMutationResult.uncertain(
        error: ApiError.dartHttpClient(TimeoutException("relay response lost")),
      );

      await service.startAll();
      connection.emitProgress(_completed("codex", newProjects: 1, newSessions: 1));

      expect(
        service.state.value.isLive,
        isTrue,
        reason: "the request may have landed, so the harness is not written off",
      );

      connection.emitProgress(_completed("claude", newProjects: 2, newSessions: 2));

      expect(
        service.state.value,
        isA<CatalogRescanSucceeded>().having((s) => s.harnessCount, "harnessCount", 2),
      );
    });

    test("counts a start the bridge explicitly refused as a failed harness", () async {
      repository.resultFor["claude"] = CatalogImportMutationResult.failure(
        error: ApiError.nonSuccessCode(errorCode: 500, rawErrorString: null),
      );

      await service.startAll();
      connection.emitProgress(_completed("codex", newProjects: 1, newSessions: 1));

      expect(
        service.state.value,
        isA<CatalogRescanPartlyFailed>()
            .having((s) => s.succeededCount, "succeededCount", 1)
            .having((s) => s.failedCount, "failedCount", 1),
      );
    });

    test("reports an unsupported bridge when every harness answers 404", () async {
      repository.resultFor["codex"] = const CatalogImportMutationResult.notFound();
      repository.resultFor["claude"] = const CatalogImportMutationResult.notFound();

      await service.startAll();

      expect(service.state.value, isA<CatalogRescanUnsupported>());
    });

    test("a joining start that answers 404 leaves the live run untouched", () async {
      build(snapshot: _snapshot(routable: const {"codex": "Codex"}));
      await service.startAll();
      repository.resultFor["ghost"] = const CatalogImportMutationResult.notFound();

      final result = await service.start(pluginId: "ghost");

      expect(result, isA<CatalogRescanStartUnsupported>());
      expect(
        (service.state.value as CatalogRescanStarting).pluginIds,
        {"codex"},
        reason: "one unknown harness must not be read as a bridge without the route",
      );

      connection.emitProgress(_completed("codex", newProjects: 1, newSessions: 1));

      expect(
        service.state.value,
        isA<CatalogRescanSucceeded>(),
        reason: "the surviving harness must still settle and refresh",
      );
    });

    test("an unsupported snapshot does not overwrite a run already in flight", () async {
      final settled = <void>[];
      service.settled.listen(settled.add);
      // A v1.6.x bridge has the import route but no management route, so a run
      // can be live while the snapshot reports unsupported.
      connection.emitProgress(const CatalogImportProgress.enumerating(
        pluginId: "codex",
        projectsSeen: 1,
        sessionsSeen: 2,
      ));
      management.emit(const PluginManagementLoadResult.unsupported());

      await service.startAll();

      expect(service.state.value.isLive, isTrue, reason: "the live run must survive");
      service.dismiss();
      expect(service.state.value.isLive, isTrue, reason: "a live run is not dismissible");

      connection.emitProgress(_completed("codex", newProjects: 3, newSessions: 3));

      expect(settled, hasLength(1), reason: "its close must still refresh the lists");
    });

    test("re-points the row at a harness still working when another settles", () async {
      await service.startAll();
      connection.emitProgress(const CatalogImportProgress.enumerating(
        pluginId: "claude",
        projectsSeen: 1,
        sessionsSeen: 9,
      ));
      expect((service.state.value as CatalogRescanRunning).activePluginName, "Claude");

      connection.emitProgress(_completed("claude", newProjects: 1, newSessions: 1));

      expect(
        service.state.value,
        isA<CatalogRescanStarting>(),
        reason: "codex has reported nothing yet, so no harness can be named",
      );
    });

    test("a targeted 404 does not claim the whole bridge cannot rescan", () async {
      // The bridge answers 404 for an unknown plugin and for a deselected one
      // alike, so one 404 says nothing about whether the route exists.
      repository.resultFor["codex"] = const CatalogImportMutationResult.notFound();

      final result = await service.start(pluginId: "codex");

      expect(result, isA<CatalogRescanStartUnsupported>(), reason: "the caller is told");
      expect(
        service.state.value,
        isA<CatalogRescanIdle>(),
        reason: "but no bridge-wide claim reaches the other surfaces",
      );
    });

    test("a start resolving after its run already settled leaves the row alone", () async {
      final settled = <void>[];
      service.settled.listen(settled.add);
      final release = Completer<CatalogImportMutationResult>();
      repository.pendingFor["claude"] = release.future;

      final pending = service.startAll();
      // Both harnesses fail over SSE while claude's response is still in flight.
      connection.emitProgress(const CatalogImportProgress.failed(pluginId: "codex", message: "x"));
      connection.emitProgress(const CatalogImportProgress.failed(pluginId: "claude", message: "y"));
      expect(service.state.value, isA<CatalogRescanFailed>());

      release.complete(const CatalogImportMutationResult.accepted());
      await pending;

      expect(
        service.state.value,
        isA<CatalogRescanFailed>(),
        reason: "a diagnostic the user has not read must not erase itself",
      );
      expect(settled, hasLength(1), reason: "and the lists must not refresh twice");
    });

    test("reports an unsupported bridge from an unsupported snapshot, issuing no request", () async {
      build(snapshot: const PluginManagementLoadResult.unsupported());

      await service.startAll();

      expect(service.state.value, isA<CatalogRescanUnsupported>());
      expect(repository.startedPluginIds, isEmpty);
    });

    test("a targeted start on an unsupported bridge tells the caller", () async {
      build(snapshot: const PluginManagementLoadResult.unsupported());

      expect(await service.start(pluginId: "codex"), isA<CatalogRescanStartUnsupported>());
    });

    test("a targeted start reports a rejection instead of skipping it", () async {
      repository.resultFor["codex"] = const CatalogImportMutationResult.unavailable();

      expect(await service.start(pluginId: "codex"), isA<CatalogRescanStartNotImportable>());
    });

    test("a failed targeted start retains its cause for the log", () async {
      final cause = ApiError.nonSuccessCode(errorCode: 500, rawErrorString: null);
      repository.resultFor["codex"] = CatalogImportMutationResult.failure(error: cause);

      final result = await service.start(pluginId: "codex");

      expect(result, isA<CatalogRescanStartFailed>().having((r) => r.cause, "cause", cause));
    });

    test("cancel fans out one request per member, including while starting", () async {
      await service.startAll();
      expect(service.state.value, isA<CatalogRescanStarting>());

      await service.cancel();

      expect(repository.cancelledPluginIds, unorderedEquals(["codex", "claude"]));
      expect(service.state.value, isA<CatalogRescanIdle>());
    });

    test("adopts an unsolicited rescan and settles it without claiming a summary", () async {
      final settled = <void>[];
      service.settled.listen(settled.add);

      connection.emitProgress(const CatalogImportProgress.enumerating(
        pluginId: "codex",
        projectsSeen: 1,
        sessionsSeen: 4,
      ));
      expect(service.state.value, isA<CatalogRescanRunning>());

      connection.emitProgress(_completed("codex", newProjects: 5, newSessions: 5));

      expect(
        service.state.value,
        isA<CatalogRescanIdle>(),
        reason: "a run this client did not start cannot honestly summarise itself",
      );
      expect(settled, hasLength(1), reason: "the lists still have to refresh");
    });

    test("ignores an unsolicited terminal event for a run it never saw", () async {
      connection.emitProgress(_completed("codex", newProjects: 3, newSessions: 3));

      expect(service.state.value, isA<CatalogRescanIdle>());
    });

    test("announces the close whenever a live operation ends", () async {
      final settled = <void>[];
      service.settled.listen(settled.add);

      await service.startAll();
      connection.emitProgress(_completed("codex", newProjects: 1, newSessions: 1));
      connection.emitProgress(_completed("claude", newProjects: 1, newSessions: 1));

      expect(settled, hasLength(1));
    });

    test("a reconnect adopts an in-flight import from the status read", () async {
      build(initialStatus: const ConnectionStatus.disconnected());
      repository.statuses = const CatalogImportStatusesResult.supported(
        statuses: [
          CatalogImportProgress.enumerating(pluginId: "codex", projectsSeen: 1, sessionsSeen: 7),
        ],
      );

      connection.emitStatus(_connected);
      await pumpEventQueue();

      expect(
        service.state.value,
        isA<CatalogRescanRunning>().having((s) => s.sessionsSeen, "sessionsSeen", 7),
      );
    });

    test("a reconnect discards terminal statuses instead of announcing a stale success", () async {
      build(initialStatus: const ConnectionStatus.disconnected());
      repository.statuses = CatalogImportStatusesResult.supported(
        statuses: [
          _completed("codex", newProjects: 0, newSessions: 0),
          _completed("claude", newProjects: 40, newSessions: 40),
        ],
      );

      connection.emitStatus(_connected);
      await pumpEventQueue();

      expect(service.state.value, isA<CatalogRescanIdle>());
    });

    test("a disconnect clears an active rescan and announces the close", () async {
      final settled = <void>[];
      service.settled.listen(settled.add);
      await service.startAll();
      expect(service.state.value, isA<CatalogRescanStarting>());

      connection.emitStatus(const ConnectionStatus.disconnected());
      await pumpEventQueue();

      expect(service.state.value, isA<CatalogRescanIdle>());
      expect(settled, hasLength(1));
    });
  });
}

const _config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: null);
const _health = HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false);
const _connected = ConnectionStatus.connected(config: _config, health: _health);

CatalogImportCompleted _completed(
  String pluginId, {
  int? newProjects,
  int? newSessions,
  int totals = 1,
}) {
  return CatalogImportProgress.completed(
    pluginId: pluginId,
    projectsImported: totals,
    sessionsImported: totals,
    newItems: newProjects == null || newSessions == null
        ? null
        : CatalogImportNewItems(projects: newProjects, sessions: newSessions),
    completedAt: 1,
  ) as CatalogImportCompleted;
}

PluginManagementLoadResult _snapshot({
  required Map<String, String> routable,
  String bridgeId = "bridge-1",
}) {
  return PluginManagementLoadResult.supported(
    response: PluginManagementResponse(
      snapshotToken: "token",
      bridgeId: bridgeId,
      defaultPluginId: null,
      defaultIdleTimeoutMins: 10,
      plugins: [
        for (final MapEntry(key: id, value: name) in routable.entries)
          PluginManagementMetadata(
            setup: PluginSetupMetadata(
              id: id,
              displayName: name,
              state: PluginSetupState.ready,
              runtimeVersion: null,
              actionHint: null,
            ),
            runtimeState: PluginRuntimeState.dormant,
            workState: PluginManagementWorkState.idle,
            idleTimeoutMins: 10,
            hasIdleTimeoutOverride: false,
            managementCapabilities: const {PluginManagementCapability.lifecycle},
            actionHint: null,
          ),
      ],
    ),
    refreshError: null,
  );
}

class _FakePluginRepository() implements PluginRepository {
  final Map<String, CatalogImportMutationResult> resultFor = {};
  final Map<String, Future<CatalogImportMutationResult>> pendingFor = {};
  final List<String> startedPluginIds = [];
  final List<String> cancelledPluginIds = [];
  CatalogImportStatusesResult statuses = const CatalogImportStatusesResult.supported(statuses: []);

  @override
  Future<CatalogImportMutationResult> startCatalogImport({required String pluginId}) async {
    startedPluginIds.add(pluginId);
    if (pendingFor.remove(pluginId) case final pending?) return await pending;
    return resultFor[pluginId] ?? const CatalogImportMutationResult.accepted();
  }

  @override
  Future<CatalogImportMutationResult> cancelCatalogImport({required String pluginId}) async {
    cancelledPluginIds.add(pluginId);
    return const CatalogImportMutationResult.accepted();
  }

  @override
  Future<CatalogImportStatusesResult> getCatalogImportStatuses() async => statuses;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeManagementService(PluginManagementLoadResult initial) implements PluginManagementService {
  final BehaviorSubject<PluginManagementLoadResult> _snapshots = BehaviorSubject.seeded(initial);

  @override
  ValueStream<PluginManagementLoadResult> get snapshots => _snapshots.stream;

  void emit(PluginManagementLoadResult snapshot) => _snapshots.add(snapshot);

  Future<void> dispose() => _snapshots.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeConnectionService({required ConnectionStatus initialStatus}) implements ConnectionService {
  final BehaviorSubject<ConnectionStatus> _statuses = BehaviorSubject.seeded(initialStatus);
  final StreamController<SseEvent> _events = StreamController.broadcast(sync: true);
  final StreamController<void> _stale = StreamController.broadcast(sync: true);

  @override
  ConnectionStatus get currentStatus => _statuses.value;

  @override
  ValueStream<ConnectionStatus> get status => _statuses.stream;

  @override
  Stream<SseEvent> get events => _events.stream;

  @override
  Stream<void> get dataMayBeStale => _stale.stream;

  void emitStatus(ConnectionStatus status) => _statuses.add(status);

  void emitProgress(CatalogImportProgress progress) {
    _events.add(SseEvent(data: SesoriSseEvent.catalogImportProgress(progress: progress)));
  }

  @override
  Future<void> dispose() async {
    await Future.wait([_statuses.close(), _events.close(), _stale.close()]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
