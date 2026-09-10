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
        isA<CatalogRescanPreparingOne>()
            .having((s) => s.pendingPluginName, "pendingPluginName", "Codex")
            .having((s) => s.finishedHarnessCount, "finishedHarnessCount", 0)
            .having((s) => s.pluginIds, "pluginIds", {"codex", "claude"}),
      );
    });

    test("keeps first unfinished harness focused while later harness reports progress", () async {
      await service.startAll();

      connection.emitProgress(
        const CatalogImportProgress.enumerating(
          pluginId: "claude",
          projectsSeen: 2,
          sessionsSeen: 9,
        ),
      );
      expect(
        service.state.value,
        isA<CatalogRescanPreparingOne>()
            .having((s) => s.pendingPluginName, "pendingPluginName", "Codex")
            .having((s) => s.finishedHarnessCount, "finishedHarnessCount", 0),
        reason: "a later harness must not steal focus before Codex reports",
      );

      connection.emitProgress(
        const CatalogImportProgress.committing(
          pluginId: "claude",
          projectsSeen: 2,
          sessionsSeen: 9,
        ),
      );
      expect(
        service.state.value,
        isA<CatalogRescanPreparingOne>().having((s) => s.pendingPluginName, "pendingPluginName", "Codex"),
        reason: "background phase changes must not change the selected harness",
      );
    });

    test("shows background completion in count while focus remains stable", () async {
      await service.startAll();

      connection.emitProgress(_completed("claude", newProjects: 1, newSessions: 2));

      expect(
        service.state.value,
        isA<CatalogRescanPreparingOne>()
            .having((s) => s.pendingPluginName, "pendingPluginName", "Codex")
            .having((s) => s.finishedHarnessCount, "finishedHarnessCount", 1)
            .having((s) => s.pluginIds.length, "total harness count", 2),
        reason: "background completion is visible without moving focus",
      );

      connection.emitProgress(
        const CatalogImportProgress.enumerating(
          pluginId: "codex",
          projectsSeen: 1,
          sessionsSeen: 3,
        ),
      );
      expect(
        service.state.value,
        isA<CatalogRescanReading>()
            .having((s) => s.activePluginName, "activePluginName", "Codex")
            .having((s) => s.finishedHarnessCount, "finishedHarnessCount", 1),
      );
    });

    test("hands focus off after terminal progress and skips finished members", () async {
      build(snapshot: _snapshot(routable: const {"codex": "Codex", "claude": "Claude", "cursor": "Cursor"}));
      await service.startAll();

      // Claude finishes out of order while Codex is still the first member.
      connection.emitProgress(_completed("claude", newProjects: 0, newSessions: 0));
      expect(
        service.state.value,
        isA<CatalogRescanPreparingOne>()
            .having((s) => s.pendingPluginName, "pendingPluginName", "Codex")
            .having((s) => s.finishedHarnessCount, "finishedHarnessCount", 1),
      );

      connection.emitProgress(_completed("codex", newProjects: 0, newSessions: 0));
      expect(
        service.state.value,
        isA<CatalogRescanPreparingOne>()
            .having((s) => s.pendingPluginName, "pendingPluginName", "Cursor")
            .having((s) => s.finishedHarnessCount, "finishedHarnessCount", 2),
        reason: "handoff skips Claude, which already finished",
      );
    });

    test("hands focus off when the first harness is rejected", () async {
      repository.resultFor["codex"] = const CatalogImportMutationResult.unavailable();

      await service.startAll();

      expect(
        service.state.value,
        isA<CatalogRescanPreparingOne>()
            .having((s) => s.pendingPluginName, "pendingPluginName", "Claude")
            .having((s) => s.finishedHarnessCount, "finishedHarnessCount", 0)
            .having((s) => s.pluginIds, "pluginIds", {"claude"}),
      );
    });

    for (final (label, outcome, finishedHarnessCount, pluginIds) in [
      ("unavailable", const CatalogImportMutationResult.unavailable(), 0, const {"claude"}),
      ("not found", const CatalogImportMutationResult.notFound(), 0, const {"claude"}),
      (
        "failure",
        CatalogImportMutationResult.failure(error: ApiError.nonSuccessCode(errorCode: 500, rawErrorString: null)),
        1,
        const {"codex", "claude"},
      ),
    ]) {
      test("hands focus off after $label while another start is pending", () async {
        final pendingStart = Completer<CatalogImportMutationResult>();
        repository.resultFor["codex"] = outcome;
        repository.pendingFor["claude"] = pendingStart.future;

        final starting = service.startAll();
        await pumpEventQueue();

        expect(repository.startedPluginIds, ["codex", "claude"]);
        expect(
          service.state.value,
          isA<CatalogRescanPreparingOne>()
              .having((s) => s.pendingPluginName, "pendingPluginName", "Claude")
              .having((s) => s.finishedHarnessCount, "finishedHarnessCount", finishedHarnessCount)
              .having((s) => s.pluginIds, "pluginIds", pluginIds),
          reason: "the first definitive response must update focus/counts without waiting for the batch",
        );

        pendingStart.complete(const CatalogImportMutationResult.accepted());
        await starting;
      });
    }

    test("counts failed and cancelled members as finished", () async {
      build(snapshot: _snapshot(routable: const {"codex": "Codex", "claude": "Claude", "cursor": "Cursor"}));
      await service.startAll();

      connection.emitProgress(const CatalogImportProgress.cancelled(pluginId: "claude"));
      expect(
        service.state.value,
        isA<CatalogRescanPreparingOne>()
            .having((s) => s.pendingPluginName, "pendingPluginName", "Codex")
            .having((s) => s.finishedHarnessCount, "finishedHarnessCount", 1),
      );

      connection.emitProgress(const CatalogImportProgress.failed(pluginId: "codex", message: "failed"));
      expect(
        service.state.value,
        isA<CatalogRescanPreparingOne>()
            .having((s) => s.pendingPluginName, "pendingPluginName", "Cursor")
            .having((s) => s.finishedHarnessCount, "finishedHarnessCount", 2),
      );
    });

    test("bootstraps management before deciding which harnesses to scan", () async {
      build(snapshot: const PluginManagementLoadResult.loading());
      management.nextRefreshSnapshot = _snapshot(routable: const {"codex": "Codex"});

      await service.startAll();

      expect(management.refreshCalls, 1);
      expect(repository.startedPluginIds, ["codex"]);
      expect(
        service.state.value,
        isA<CatalogRescanPreparingOne>().having((s) => s.pendingPluginName, "pendingPluginName", "Codex"),
      );
    });

    test("names the enumerating harness once progress arrives", () async {
      await service.startAll();

      connection.emitProgress(
        const CatalogImportProgress.enumerating(
          pluginId: "codex",
          projectsSeen: 3,
          sessionsSeen: 42,
        ),
      );

      expect(
        service.state.value,
        isA<CatalogRescanReading>()
            .having((s) => s.activePluginName, "activePluginName", "Codex")
            .having((s) => s.sessionsSeen, "sessionsSeen", 42),
      );
    });

    test("uses fresh management state only to confirm harness startup", () async {
      build(
        snapshot: _runtimeSnapshot(
          pluginId: "codex",
          name: "Codex",
          state: PluginRuntimeState.dormant,
          refreshError: null,
        ),
      );
      await service.startAll();
      connection.emitProgress(
        const CatalogImportProgress.enumerating(
          pluginId: "codex",
          projectsSeen: 0,
          sessionsSeen: 0,
        ),
      );
      expect(service.state.value, isA<CatalogRescanReading>());

      management.emit(
        _runtimeSnapshot(
          pluginId: "codex",
          name: "Codex",
          state: PluginRuntimeState.starting,
          refreshError: null,
        ),
      );
      await pumpEventQueue();
      expect(
        service.state.value,
        isA<CatalogRescanStarting>().having((s) => s.activePluginName, "activePluginName", "Codex"),
      );

      management.emit(
        _runtimeSnapshot(
          pluginId: "codex",
          name: "Codex",
          state: PluginRuntimeState.active,
          refreshError: null,
        ),
      );
      await pumpEventQueue();
      expect(service.state.value, isA<CatalogRescanReading>());
    });

    test("does not infer startup from a retained snapshot after refresh failure", () async {
      build(
        snapshot: _runtimeSnapshot(
          pluginId: "codex",
          name: "Codex",
          state: PluginRuntimeState.starting,
          refreshError: ApiError.generic(),
        ),
      );
      await service.startAll();
      connection.emitProgress(
        const CatalogImportProgress.enumerating(
          pluginId: "codex",
          projectsSeen: 0,
          sessionsSeen: 0,
        ),
      );
      await pumpEventQueue();

      expect(service.state.value, isA<CatalogRescanReading>());
    });

    test("reports the committing harness as saving", () async {
      build(snapshot: _snapshot(routable: const {"codex": "Codex"}));
      await service.startAll();

      connection.emitProgress(
        const CatalogImportProgress.committing(
          pluginId: "codex",
          projectsSeen: 2,
          sessionsSeen: 8,
        ),
      );

      expect(
        service.state.value,
        isA<CatalogRescanSaving>().having((s) => s.activePluginName, "activePluginName", "Codex"),
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
      connection.emitProgress(
        const CatalogImportProgress.failed(
          pluginId: "claude",
          message: "boom: /Users/someone/secret/path",
        ),
      );

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
          isA<CatalogRescanPreparingOne>()
              .having((s) => s.pendingPluginName, "pendingPluginName", "Codex")
              .having((s) => s.finishedHarnessCount, "finishedHarnessCount", 0),
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
        isA<CatalogRescanPreparingOne>()
            .having((s) => s.pendingPluginName, "pendingPluginName", "Codex")
            .having((s) => s.finishedHarnessCount, "finishedHarnessCount", 0),
        reason: "retained progress from the previous run must be cleared",
      );
      connection.emitProgress(_completed("codex", newProjects: 0, newSessions: 0));
      expect(
        service.state.value,
        isA<CatalogRescanPreparingOne>().having((s) => s.pendingPluginName, "pendingPluginName", "Claude"),
        reason: "claude has not settled",
      );
    });

    test("a targeted start joins the live operation instead of replacing it", () async {
      build(snapshot: _snapshot(routable: const {"codex": "Codex"}));
      await service.startAll();
      expect((service.state.value as CatalogRescanPreparingOne).pluginIds, {"codex"});

      final result = await service.start(pluginId: "claude");

      expect(result, isA<CatalogRescanStartAccepted>());
      expect(
        (service.state.value as CatalogRescanPreparingOne).pluginIds,
        {"codex", "claude"},
        reason: "codex must stay in aggregation and cancellation",
      );
    });

    test("skips a harness the bridge reports unavailable, without failing the run", () async {
      repository.resultFor["claude"] = const CatalogImportMutationResult.unavailable();

      await service.startAll();

      expect((service.state.value as CatalogRescanPreparingOne).pluginIds, {"codex"});
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
        (service.state.value as CatalogRescanPreparingOne).pluginIds,
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
      final catalogChanges = <void>[];
      service.catalogChanged.listen(catalogChanges.add);
      // A v1.6.x bridge has the import route but no management route, so a run
      // can be live while the snapshot reports unsupported.
      connection.emitProgress(
        const CatalogImportProgress.enumerating(
          pluginId: "codex",
          projectsSeen: 1,
          sessionsSeen: 2,
        ),
      );
      management.emit(const PluginManagementLoadResult.unsupported());

      await service.startAll();

      expect(service.state.value.isLive, isTrue, reason: "the live run must survive");
      service.dismiss();
      expect(service.state.value.isLive, isTrue, reason: "a live run is not dismissible");

      connection.emitProgress(_completed("codex", newProjects: 3, newSessions: 3));

      expect(catalogChanges, hasLength(1), reason: "its committed import must refresh the lists");
    });

    test("keeps the first harness focused until it settles", () async {
      await service.startAll();
      connection.emitProgress(
        const CatalogImportProgress.enumerating(
          pluginId: "claude",
          projectsSeen: 1,
          sessionsSeen: 9,
        ),
      );
      expect(
        service.state.value,
        isA<CatalogRescanPreparingOne>().having((s) => s.pendingPluginName, "pendingPluginName", "Codex"),
      );

      connection.emitProgress(_completed("claude", newProjects: 1, newSessions: 1));

      expect(
        service.state.value,
        isA<CatalogRescanPreparingOne>()
            .having((s) => s.pendingPluginName, "pendingPluginName", "Codex")
            .having((s) => s.finishedHarnessCount, "finishedHarnessCount", 1),
        reason: "background completion must not steal focus",
      );

      connection.emitProgress(
        const CatalogImportProgress.enumerating(
          pluginId: "codex",
          projectsSeen: 1,
          sessionsSeen: 2,
        ),
      );
      expect(
        service.state.value,
        isA<CatalogRescanReading>().having((s) => s.activePluginName, "activePluginName", "Codex"),
        reason: "focus advances after the first harness settles",
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

    test("a start resolving after its failed run settled leaves the row alone", () async {
      final catalogChanges = <void>[];
      service.catalogChanged.listen(catalogChanges.add);
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
      expect(catalogChanges, isEmpty, reason: "a failed import did not change the catalog");
    });

    test("reports an unsupported bridge from an unsupported snapshot, issuing no request", () async {
      build(snapshot: const PluginManagementLoadResult.unsupported());

      await service.startAll();

      expect(service.state.value, isA<CatalogRescanUnsupported>());
      expect(repository.startedPluginIds, isEmpty);
    });

    // The gesture that calls this has already told the user a scan started, so
    // a fan-out with nothing to fan out to has to say so rather than return.
    test("reports that there is no harness when the snapshot names none that is routable", () async {
      build(snapshot: _snapshot(routable: const {}));

      await service.startAll();

      expect(service.state.value, isA<CatalogRescanNoHarness>());
      expect(repository.startedPluginIds, isEmpty);
    });

    test("reports that there is no harness while no snapshot has arrived", () async {
      build(snapshot: const PluginManagementLoadResult.loading());

      await service.startAll();

      expect(service.state.value, isA<CatalogRescanNoHarness>());
      expect(repository.startedPluginIds, isEmpty);
    });

    test("a live run outlasts a fan-out that finds no harness", () async {
      build(snapshot: _snapshot(routable: const {"codex": "Codex"}));
      await service.startAll();
      management.emit(const PluginManagementLoadResult.loading());

      await service.startAll();

      expect(
        service.state.value,
        isA<CatalogRescanPreparingOne>(),
        reason: "the run in flight is still the truth about what is happening",
      );
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
      expect(service.state.value, isA<CatalogRescanPreparingOne>());

      await service.cancel();

      expect(repository.cancelledPluginIds, unorderedEquals(["codex", "claude"]));
      expect(service.state.value, isA<CatalogRescanIdle>());
    });

    test("adopts an unsolicited rescan and refreshes after its commit without claiming a summary", () async {
      final catalogChanges = <void>[];
      service.catalogChanged.listen(catalogChanges.add);

      connection.emitProgress(
        const CatalogImportProgress.enumerating(
          pluginId: "codex",
          projectsSeen: 1,
          sessionsSeen: 4,
        ),
      );
      expect(service.state.value, isA<CatalogRescanReading>());

      connection.emitProgress(_completed("codex", newProjects: 5, newSessions: 5));

      expect(
        service.state.value,
        isA<CatalogRescanIdle>(),
        reason: "a run this client did not start cannot honestly summarise itself",
      );
      expect(catalogChanges, hasLength(1), reason: "the lists still have to refresh");
    });

    test("announces an unsolicited terminal commit without reopening a row", () async {
      final catalogChanges = <void>[];
      service.catalogChanged.listen(catalogChanges.add);

      connection.emitProgress(_completed("codex", newProjects: 3, newSessions: 3));

      expect(service.state.value, isA<CatalogRescanIdle>());
      expect(catalogChanges, hasLength(1));
    });

    test("ignores a zero-count hydration completion", () async {
      final catalogChanges = <void>[];
      service.catalogChanged.listen(catalogChanges.add);

      connection.emitProgress(_completed("codex", newProjects: 0, newSessions: 0, totals: 0));

      expect(catalogChanges, isEmpty);
      expect(service.state.value, isA<CatalogRescanIdle>());
    });

    test("announces each durable catalog commit", () async {
      final catalogChanges = <void>[];
      service.catalogChanged.listen(catalogChanges.add);

      await service.startAll();
      connection.emitProgress(_completed("codex", newProjects: 1, newSessions: 1));
      connection.emitProgress(_completed("claude", newProjects: 1, newSessions: 1));

      expect(catalogChanges, hasLength(2));
    });

    test("an operation stops claiming a summary once an outside harness joins", () async {
      await service.startAll();

      // A third harness this client never dispatched appears from elsewhere.
      connection.emitProgress(
        const CatalogImportProgress.enumerating(
          pluginId: "outsider",
          projectsSeen: 1,
          sessionsSeen: 1,
        ),
      );
      connection.emitProgress(_completed("codex", newProjects: 1, newSessions: 1));
      connection.emitProgress(_completed("claude", newProjects: 1, newSessions: 1));
      connection.emitProgress(_completed("outsider", newProjects: 1, newSessions: 1));

      expect(
        service.state.value,
        isA<CatalogRescanIdle>(),
        reason: "it can no longer vouch for every member, so it claims nothing",
      );
    });

    test("announces a commit that arrives after an immediate cancel", () async {
      build(snapshot: _snapshot(routable: const {"codex": "Codex"}));
      final catalogChanges = <void>[];
      service.catalogChanged.listen(catalogChanges.add);
      await service.startAll();

      await service.cancel();
      expect(service.state.value, isA<CatalogRescanIdle>(), reason: "the row still closes immediately");

      connection.emitProgress(_completed("codex", newProjects: 1, newSessions: 1));

      expect(service.state.value, isA<CatalogRescanIdle>());
      expect(catalogChanges, hasLength(1), reason: "the completed atomic commit still invalidates lists");
    });

    test("cancel waits for a start still in flight before sending its DELETE", () async {
      final release = Completer<CatalogImportMutationResult>();
      repository.pendingFor["codex"] = release.future;
      final pending = service.startAll();

      final cancelling = service.cancel();
      await pumpEventQueue();

      expect(
        repository.cancelledPluginIds,
        isEmpty,
        reason: "a DELETE that overtakes its POST cancels nothing",
      );

      release.complete(const CatalogImportMutationResult.accepted());
      await pending;
      await cancelling;

      expect(repository.cancelledPluginIds, contains("codex"));
    });

    test("a rescan started during a cancellation does not inherit its DELETEs", () async {
      final release = Completer<CatalogImportMutationResult>();
      repository.pendingFor["codex"] = release.future;
      final firstRun = service.startAll();

      final cancelling = service.cancel();
      // The user taps rescan again while the cancellation is still waiting for
      // the first start to come back.
      final secondRun = service.startAll();
      await pumpEventQueue();

      expect(
        repository.startedPluginIds.where((id) => id == "codex"),
        hasLength(1),
        reason: "the second start must not begin inside the cancellation window",
      );

      release.complete(const CatalogImportMutationResult.accepted());
      await firstRun;
      await cancelling;
      await secondRun;

      expect(repository.cancelledPluginIds, contains("codex"));
      expect(
        repository.startedPluginIds.where((id) => id == "codex"),
        hasLength(2),
        reason: "and must run once the cancellation has dispatched",
      );
    });

    test("a member restarted from outside stops the run claiming a summary", () async {
      await service.startAll();
      connection.emitProgress(_completed("codex", newProjects: 1, newSessions: 1));

      // Another surface restarts codex while claude is still running.
      connection.emitProgress(
        const CatalogImportProgress.enumerating(
          pluginId: "codex",
          projectsSeen: 1,
          sessionsSeen: 1,
        ),
      );
      connection.emitProgress(_completed("codex", newProjects: 50, newSessions: 50));
      connection.emitProgress(_completed("claude", newProjects: 1, newSessions: 1));

      expect(
        service.state.value,
        isA<CatalogRescanIdle>(),
        reason: "the second codex run's counts are not this operation's to report",
      );
    });

    test("reads in-flight imports again once a new bridge identity lands", () async {
      build(initialStatus: const ConnectionStatus.disconnected());
      repository.statuses = const CatalogImportStatusesResult.supported(
        statuses: [
          CatalogImportProgress.enumerating(pluginId: "codex", projectsSeen: 1, sessionsSeen: 6),
        ],
      );
      connection.emitStatus(_connected);
      await pumpEventQueue();
      expect(service.state.value, isA<CatalogRescanReading>());

      // The management snapshot for the newly connected bridge arrives after
      // the recovery read and reports a different identity.
      management.emit(_snapshot(routable: const {"codex": "Codex"}, bridgeId: "bridge-2"));
      await pumpEventQueue();

      expect(
        service.state.value,
        isA<CatalogRescanReading>().having((s) => s.sessionsSeen, "sessionsSeen", 6),
        reason: "the reset for the new identity must be followed by another read",
      );
    });

    test("a stale event from a cancelled run cannot reopen it", () async {
      build(snapshot: _snapshot(routable: const {"codex": "Codex"}));
      final release = Completer<CatalogImportMutationResult>();
      repository.pendingFor["codex"] = release.future;
      final firstRun = service.startAll();
      final cancelling = service.cancel();

      // A progress event from the run being cancelled arrives before the
      // DELETE has gone out.
      connection.emitProgress(
        const CatalogImportProgress.enumerating(
          pluginId: "codex",
          projectsSeen: 1,
          sessionsSeen: 3,
        ),
      );

      expect(
        service.state.value,
        isA<CatalogRescanIdle>(),
        reason: "a cancelled run must not reopen itself as an observed operation",
      );

      release.complete(const CatalogImportMutationResult.accepted());
      await firstRun;
      await cancelling;

      // The next rescan must still be able to claim its own summary.
      await service.startAll();
      connection.emitProgress(_completed("codex", newProjects: 2, newSessions: 2));

      expect(service.state.value, isA<CatalogRescanSucceeded>());
    });

    test("an outside cancellation closes quietly instead of showing a failure", () async {
      build(snapshot: _snapshot(routable: const {"codex": "Codex"}));
      final catalogChanges = <void>[];
      service.catalogChanged.listen(catalogChanges.add);
      await service.startAll();

      // Another connected surface cancelled this harness.
      connection.emitProgress(const CatalogImportProgress.cancelled(pluginId: "codex"));

      expect(
        service.state.value,
        isA<CatalogRescanIdle>(),
        reason: "a deliberate cancellation elsewhere is not this run's failure",
      );
      expect(catalogChanges, isEmpty);
    });

    test("recovers an in-flight import when resolved onto a live connection", () async {
      repository = _FakePluginRepository();
      connection = _FakeConnectionService(initialStatus: _connected);
      management = _FakeManagementService(_snapshot(routable: const {"codex": "Codex"}));
      repository.statuses = const CatalogImportStatusesResult.supported(
        statuses: [
          CatalogImportProgress.enumerating(pluginId: "codex", projectsSeen: 1, sessionsSeen: 5),
        ],
      );

      // No false-to-true transition ever arrives for a service built while the
      // connection is already up.
      service = CatalogRescanService(
        pluginRepository: repository,
        managementService: management,
        connectionService: connection,
      );
      await pumpEventQueue();

      expect(
        service.state.value,
        isA<CatalogRescanReading>().having((s) => s.sessionsSeen, "sessionsSeen", 5),
      );
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
        isA<CatalogRescanReading>().having((s) => s.sessionsSeen, "sessionsSeen", 7),
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

    test("a disconnect clears an active rescan without claiming a catalog change", () async {
      final catalogChanges = <void>[];
      service.catalogChanged.listen(catalogChanges.add);
      await service.startAll();
      expect(service.state.value, isA<CatalogRescanPreparingOne>());

      connection.emitStatus(const ConnectionStatus.disconnected());
      await pumpEventQueue();

      expect(service.state.value, isA<CatalogRescanIdle>());
      expect(catalogChanges, isEmpty);
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

PluginManagementLoadResult _runtimeSnapshot({
  required String pluginId,
  required String name,
  required PluginRuntimeState state,
  required ApiError? refreshError,
}) {
  return PluginManagementLoadResult.supported(
    response: PluginManagementResponse(
      snapshotToken: "runtime-$state",
      bridgeId: "bridge-1",
      defaultPluginId: null,
      defaultIdleTimeoutMins: 10,
      plugins: [
        PluginManagementMetadata(
          setup: PluginSetupMetadata(
            id: pluginId,
            displayName: name,
            state: PluginSetupState.ready,
            runtimeVersion: null,
            actionHint: null,
          ),
          runtimeState: state,
          workState: PluginManagementWorkState.idle,
          idleTimeoutMins: 10,
          hasIdleTimeoutOverride: false,
          managementCapabilities: const {PluginManagementCapability.lifecycle},
          actionHint: null,
        ),
      ],
    ),
    refreshError: refreshError,
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

  PluginManagementLoadResult? nextRefreshSnapshot;
  int refreshCalls = 0;

  @override
  ValueStream<PluginManagementLoadResult> get snapshots => _snapshots.stream;

  @override
  Future<void> refresh() async {
    refreshCalls++;
    if (nextRefreshSnapshot case final snapshot?) emit(snapshot);
  }

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
