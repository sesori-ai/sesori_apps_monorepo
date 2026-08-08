import "dart:async";
import "dart:collection";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_event.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_management_result.dart";
import "package:sesori_dart_core/src/repositories/plugin_repository.dart";
import "package:sesori_dart_core/src/services/plugin_management_service.dart";
import "package:sesori_dart_core/src/services/product_analytics_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockProductAnalyticsService extends Mock implements ProductAnalyticsService {}

void main() {
  late _MockProductAnalyticsService analytics;
  late List<ProductAnalyticsEvent> reportedEvents;

  setUpAll(() {
    registerFallbackValue(const ProductAnalyticsEvent.sessionAbortSucceeded());
  });

  setUp(() {
    analytics = _MockProductAnalyticsService();
    reportedEvents = [];
    when(
      () => analytics.logEvent(event: any(named: "event"), occurredAtUtc: any(named: "occurredAtUtc")),
    ).thenAnswer((invocation) async {
      reportedEvents.add(invocation.namedArguments[#event]! as ProductAnalyticsEvent);
      return AnalyticsDeliveryResult.acceptedBySdk;
    });
  });

  group("refresh synchronization", () {
    test("already-connected construction performs exactly one replay-triggered load", () async {
      final repository = _FakePluginRepository()..queueLoad(_supported(_response(token: "one")));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });

      await _waitFor(() => repository.loadCalls == 1);
      await _waitFor(() => service.snapshots.hasValue);

      expect(repository.loadCalls, 1);
      expect(_supportedResponse(service).snapshotToken, "one");
    });

    test("disconnected construction defers its first load until connected", () async {
      final repository = _FakePluginRepository()..queueLoad(_supported(_response(token: "connected")));
      final connection = _FakeConnectionService(initialStatus: const ConnectionStatus.disconnected());
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });

      await _pump();
      expect(repository.loadCalls, isZero);

      connection.emitStatus(_connected);
      await _waitFor(() => service.snapshots.hasValue);
      expect(repository.loadCalls, 1);
    });

    test("triggers during an active load coalesce into one trailing load", () async {
      final first = Completer<PluginManagementLoadResult>();
      final repository = _FakePluginRepository()
        ..queueLoad(first.future)
        ..queueLoad(_supported(_response(token: "trailing")));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => repository.loadCalls == 1);

      connection
        ..emitStale()
        ..emitStale();
      await _pump();
      first.complete(_supported(_response(token: "first")));
      await _waitFor(() => repository.loadCalls == 2);
      await _waitFor(() => service.snapshots.hasValue && _supportedResponse(service).snapshotToken == "trailing");

      expect(repository.loadCalls, 2);
      expect(_supportedResponse(service).snapshotToken, "trailing");
    });

    test("management SSE suppresses equal tokens while replay loss always refreshes", () async {
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "same")))
        ..queueLoad(_supported(_response(token: "changed")))
        ..queueLoad(_supported(_response(token: "replay")));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      connection.emitManagementChanged(snapshotToken: "same");
      await _pump();
      expect(repository.loadCalls, 1);

      connection.emitManagementChanged(snapshotToken: "different");
      await _waitFor(() => repository.loadCalls == 2);
      connection.emitStale();
      await _waitFor(() => repository.loadCalls == 3);

      expect(_supportedResponse(service).snapshotToken, "replay");
    });

    test("failed refresh retains same-bridge data and retries only after another trigger", () async {
      final error = ApiError.generic();
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "initial", bridgeId: "br_a")))
        ..queueLoad(PluginManagementLoadResult.failure(error: error))
        ..queueLoad(_supported(_response(token: "recovered", bridgeId: "br_a")));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      await service.refresh();
      final failedRefresh = service.snapshots.value as PluginManagementLoadResultSupported;
      expect(failedRefresh.response.snapshotToken, "initial");
      expect(failedRefresh.refreshError, same(error));
      await _pump();
      expect(repository.loadCalls, 2);

      connection.emitStale();
      await _waitFor(() => repository.loadCalls == 3);
      expect(_supportedResponse(service).snapshotToken, "recovered");
    });

    test("first failed load after reconnect never replays the previous bridge snapshot", () async {
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "a", bridgeId: "br_a")))
        ..queueLoad(PluginManagementLoadResult.failure(error: ApiError.generic()))
        ..queueLoad(_supported(_response(token: "b", bridgeId: "br_b")));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      connection
        ..emitStatus(const ConnectionStatus.connectionLost(config: _config))
        ..emitStatus(_connected);
      await _waitFor(() => repository.loadCalls == 2);

      expect(service.snapshots.value, isA<PluginManagementLoadResultFailure>());
      await service.refresh();
      expect(_supportedResponse(service).bridgeId, "br_b");
    });

    test("reconnect invalidates the replayed snapshot until the new bridge responds", () async {
      final newBridgeLoad = Completer<PluginManagementLoadResult>();
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "a", bridgeId: "br_a")))
        ..queueLoad(newBridgeLoad.future);
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue && _supportedResponse(service).bridgeId == "br_a");

      connection
        ..emitStatus(const ConnectionStatus.connectionLost(config: _config))
        ..emitStatus(_connected);
      await _waitFor(() => repository.loadCalls == 2);

      expect(service.snapshots.value, isA<PluginManagementLoadResultLoading>());
      expect(await service.snapshots.first, isA<PluginManagementLoadResultLoading>());

      newBridgeLoad.complete(_supported(_response(token: "b", bridgeId: "br_b")));
      await _waitFor(() => service.snapshots.value is PluginManagementLoadResultSupported);
      expect(_supportedResponse(service).bridgeId, "br_b");
    });

    test("legacy null identity is retained only within its proven connection epoch", () async {
      final error = ApiError.generic();
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "legacy", bridgeId: null)))
        ..queueLoad(PluginManagementLoadResult.failure(error: error))
        ..queueLoad(PluginManagementLoadResult.failure(error: error));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      await service.refresh();
      expect(service.snapshots.value, isA<PluginManagementLoadResultSupported>());

      connection
        ..emitStatus(const ConnectionStatus.bridgeOffline(config: _config, health: _health))
        ..emitStatus(_connected);
      await _waitFor(() => repository.loadCalls == 3);
      expect(service.snapshots.value, isA<PluginManagementLoadResultFailure>());
    });

    test("an unexpected bridge identity change is confirmed by one clean load", () async {
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "a", bridgeId: "br_a")))
        ..queueLoad(_supported(_response(token: "b1", bridgeId: "br_b")))
        ..queueLoad(_supported(_response(token: "b2", bridgeId: "br_b")));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      connection.emitManagementChanged(snapshotToken: "b1");
      await _waitFor(() => repository.loadCalls == 3);

      expect(_supportedResponse(service).bridgeId, "br_b");
      expect(_supportedResponse(service).snapshotToken, "b2");
    });

    test("unsupported management replaces retained supported state", () async {
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "initial")))
        ..queueLoad(const PluginManagementLoadResult.unsupported());
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      await service.refresh();

      expect(service.snapshots.value, isA<PluginManagementLoadResultUnsupported>());
    });
  });

  group("publication fencing", () {
    test("a mutation publication supersedes an older refresh and forces a clean GET", () async {
      final oldRefresh = Completer<PluginManagementLoadResult>();
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "initial")))
        ..queueLoad(oldRefresh.future)
        ..queueLoad(_supported(_response(token: "authoritative")))
        ..queueMutation(_success(_response(token: "mutation")));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      final refresh = service.refresh();
      await _waitFor(() => repository.loadCalls == 2);
      final mutation = await service.command(
        pluginId: "one",
        request: const PluginLifecycleCommandRequest.refresh(),
      );
      expect(mutation, isA<PluginManagementMutationResultSuccess>());
      oldRefresh.complete(_supported(_response(token: "old")));
      await refresh;
      await _waitFor(() => repository.loadCalls == 3);

      expect(_supportedResponse(service).snapshotToken, "authoritative");
    });

    test("an intervening refresh makes a mutation uncertain and triggers an authoritative GET", () async {
      final mutation = Completer<PluginManagementMutationResult>();
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "initial")))
        ..queueLoad(_supported(_response(token: "refresh")))
        ..queueLoad(_supported(_response(token: "authoritative")))
        ..queueMutation(mutation.future);
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      final mutationFuture = service.command(
        pluginId: "one",
        request: const PluginLifecycleCommandRequest.refresh(),
      );
      await service.refresh();
      mutation.complete(_success(_response(token: "mutation")));
      final result = await mutationFuture;

      expect(result, isA<PluginManagementMutationResultUncertain>());
      expect(repository.loadCalls, 3);
      expect(_supportedResponse(service).snapshotToken, "authoritative");
    });

    test("disconnect during a mutation returns uncertain without publishing its response", () async {
      final mutation = Completer<PluginManagementMutationResult>();
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "initial")))
        ..queueMutation(mutation.future);
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      final mutationFuture = service.command(
        pluginId: "one",
        request: const PluginLifecycleCommandRequest.refresh(),
      );
      connection.emitStatus(const ConnectionStatus.connectionLost(config: _config));
      mutation.complete(_success(_response(token: "mutation")));

      expect(await mutationFuture, isA<PluginManagementMutationResultUncertain>());
      expect(service.snapshots.value, isA<PluginManagementLoadResultLoading>());
    });

    test("a stale rejection after reconnect becomes uncertain and awaits the authoritative refresh", () async {
      final mutation = Completer<PluginManagementMutationResult>();
      final reconnectRefresh = Completer<PluginManagementLoadResult>();
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "initial", bridgeId: "br_a")))
        ..queueLoad(reconnectRefresh.future)
        ..queueLoad(_supported(_response(token: "authoritative", bridgeId: "br_b")))
        ..queueMutation(mutation.future);
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      final mutationFuture = service.command(
        pluginId: "one",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
      );
      connection
        ..emitStatus(const ConnectionStatus.connectionLost(config: _config))
        ..emitStatus(_connected);
      await _waitFor(() => repository.loadCalls == 2);
      mutation.complete(
        PluginManagementMutationResult.conflict(conflict: _conflict(const [PluginLifecycleConflictReason.busy])),
      );
      await _pump();
      reconnectRefresh.complete(_supported(_response(token: "reconnected", bridgeId: "br_b")));

      expect(await mutationFuture, isA<PluginManagementMutationResultUncertain>());
      expect(_supportedResponse(service).bridgeId, "br_b");
      expect(_supportedResponse(service).snapshotToken, "authoritative");
    });

    test("disconnect during a refresh fences its response", () async {
      final refresh = Completer<PluginManagementLoadResult>();
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "initial")))
        ..queueLoad(refresh.future);
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      final refreshFuture = service.refresh();
      await _waitFor(() => repository.loadCalls == 2);
      connection.emitStatus(const ConnectionStatus.connectionLost(config: _config));
      await _pump();
      refresh.complete(_supported(_response(token: "late")));
      await refreshFuture;

      expect(service.snapshots.value, isA<PluginManagementLoadResultLoading>());
    });

    test("repository uncertain schedules a clean GET before returning", () async {
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "initial")))
        ..queueLoad(_supported(_response(token: "authoritative")))
        ..queueMutation(const PluginManagementMutationResult.uncertain());
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      final result = await service.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 20),
      );

      expect(result, isA<PluginManagementMutationResultUncertain>());
      expect(repository.loadCalls, 2);
      expect(_supportedResponse(service).snapshotToken, "authoritative");
    });

    test("a response for a different known bridge is fenced and refreshed", () async {
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "a", bridgeId: "br_a")))
        ..queueLoad(_supported(_response(token: "a2", bridgeId: "br_a")))
        ..queueMutation(_success(_response(token: "b", bridgeId: "br_b")));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      final result = await service.command(
        pluginId: "one",
        request: const PluginLifecycleCommandRequest.refresh(),
      );

      expect(result, isA<PluginManagementMutationResultUncertain>());
      expect(_supportedResponse(service).bridgeId, "br_a");
      expect(_supportedResponse(service).snapshotToken, "a2");
    });

    test("identity supersession fences every concurrently captured old-bridge mutation", () async {
      final firstMutation = Completer<PluginManagementMutationResult>();
      final secondMutation = Completer<PluginManagementMutationResult>();
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "a", bridgeId: "br_a")))
        ..queueLoad(_supported(_response(token: "b1", bridgeId: "br_b")))
        ..queueLoad(_supported(_response(token: "b2", bridgeId: "br_b")))
        ..queueMutation(firstMutation.future)
        ..queueMutation(secondMutation.future);
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      final first = service.command(
        pluginId: "one",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
      );
      final second = service.command(
        pluginId: "one",
        request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
      );
      firstMutation.complete(_success(_response(token: "unexpected-b", bridgeId: "br_b")));
      expect(await first, isA<PluginManagementMutationResultUncertain>());
      secondMutation.complete(_success(_response(token: "late-a", bridgeId: "br_a")));
      expect(await second, isA<PluginManagementMutationResultUncertain>());

      expect(repository.loadCalls, 3);
      expect(_supportedResponse(service).bridgeId, "br_b");
      expect(_supportedResponse(service).snapshotToken, "b2");
    });

    test("offline mutations fail without dispatch", () async {
      final repository = _FakePluginRepository();
      final connection = _FakeConnectionService(initialStatus: const ConnectionStatus.disconnected());
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });

      final result = await service.command(
        pluginId: "one",
        request: const PluginLifecycleCommandRequest.enable(),
      );

      expect(result, isA<PluginManagementMutationResultFailure>());
      expect(repository.mutationCalls, isZero);
    });
  });

  group("domain planning", () {
    late PluginManagementService service;
    late _FakeConnectionService connection;

    setUp(() {
      connection = _FakeConnectionService(initialStatus: const ConnectionStatus.disconnected());
      service = PluginManagementService(
        pluginRepository: _FakePluginRepository(),
        connectionService: connection,
        productAnalyticsService: analytics,
      );
    });

    tearDown(() async {
      await service.onDispose();
      await connection.dispose();
    });

    test("no-timeout intent maps to canonical zero", () {
      const input = PluginManagementIdleTimeoutInput.noTimeout();

      expect(
        service.planApplyAllIdleTimeout(input: input),
        isA<PluginManagementCommandPlanRequest>().having(
          (plan) => plan.request,
          "request",
          const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 0),
        ),
      );
      expect(
        service.planSetIdleTimeoutOverride(pluginId: "one", input: input),
        isA<PluginManagementCommandPlanRequest>().having(
          (plan) => plan.request,
          "request",
          const PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "one", idleTimeoutMins: 0),
        ),
      );
    });

    test("custom timeout accepts only trimmed strictly positive integers", () {
      expect(
        service.planApplyAllIdleTimeout(
          input: const PluginManagementIdleTimeoutInput.custom(input: " 15 "),
        ),
        isA<PluginManagementCommandPlanRequest>().having(
          (plan) => plan.request,
          "request",
          const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 15),
        ),
      );
      expect(
        service.planSetIdleTimeoutOverride(
          pluginId: "one",
          input: const PluginManagementIdleTimeoutInput.custom(input: "\t20\n"),
        ),
        isA<PluginManagementCommandPlanRequest>().having(
          (plan) => plan.request,
          "request",
          const PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "one", idleTimeoutMins: 20),
        ),
      );

      for (final value in ["", " ", "not a number", "1.5", "0", " 0 ", "-5", " -5 "]) {
        final input = PluginManagementIdleTimeoutInput.custom(input: value);
        expect(
          service.planApplyAllIdleTimeout(input: input),
          isA<PluginManagementCommandPlanInvalidInput>(),
          reason: "apply-all should reject '$value'",
        );
        expect(
          service.planSetIdleTimeoutOverride(pluginId: "one", input: input),
          isA<PluginManagementCommandPlanInvalidInput>(),
          reason: "override should reject '$value'",
        );
      }
    });

    test("clear override remains a distinct inheritance request", () {
      expect(
        service.planClearIdleTimeoutOverride(pluginId: "one"),
        isA<PluginManagementCommandPlanRequest>().having(
          (plan) => plan.request,
          "request",
          const PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "one"),
        ),
      );
    });

    test("force assessment requires a non-empty set of only forceable reasons", () {
      final forceable = service.assessForce(
        conflict: _conflict(const [
          PluginLifecycleConflictReason.inFlight,
          PluginLifecycleConflictReason.busy,
          PluginLifecycleConflictReason.workStateUnknown,
        ]),
        action: PluginManagementForceAction.restart,
      );
      expect(
        forceable,
        isA<PluginManagementForceAssessmentRequiresConfirmation>().having(
          (assessment) => assessment.request,
          "request",
          const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.force),
        ),
      );

      for (final reasons in <List<PluginLifecycleConflictReason>>[
        const [],
        const [PluginLifecycleConflictReason.transitioning],
        const [PluginLifecycleConflictReason.notEnabled],
        const [PluginLifecycleConflictReason.unsupported],
        const [PluginLifecycleConflictReason.unknown],
        const [PluginLifecycleConflictReason.busy, PluginLifecycleConflictReason.unknown],
      ]) {
        expect(
          service.assessForce(
            conflict: _conflict(reasons),
            action: PluginManagementForceAction.disable,
          ),
          isA<PluginManagementForceAssessmentNotForceable>(),
        );
      }
    });
  });

  test("disposal cancels triggers and fences an active load", () async {
    final activeLoad = Completer<PluginManagementLoadResult>();
    final repository = _FakePluginRepository()..queueLoad(activeLoad.future);
    final connection = _FakeConnectionService(initialStatus: _connected);
    final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
    await _waitFor(() => repository.loadCalls == 1);

    final snapshotsDone = expectLater(service.snapshots, emitsDone);
    final disposal = service.onDispose();
    activeLoad.complete(_supported(_response(token: "late")));
    await disposal;
    connection
      ..emitStale()
      ..emitManagementChanged(snapshotToken: "other")
      ..emitStatus(_connected);
    await _pump();

    await snapshotsDone;
    expect(repository.loadCalls, 1);
    await connection.dispose();
  });

  group("install progress", () {
    test("tracks phases per plugin and drops the entry on a terminal event", () async {
      final repository = _FakePluginRepository()..queueLoad(_supported(_response(token: "one")));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      connection.emitInstallProgress(pluginId: "codex", phase: PluginInstallPhase.downloading, percent: 30);
      await _pump();
      expect(
        service.installProgress.value,
        const {"codex": PluginInstallProgress(phase: PluginInstallPhase.downloading, percent: 30)},
      );

      connection.emitInstallProgress(pluginId: "codex", phase: PluginInstallPhase.extracting);
      await _pump();
      expect(
        service.installProgress.value,
        const {"codex": PluginInstallProgress(phase: PluginInstallPhase.extracting, percent: null)},
      );

      connection.emitInstallProgress(pluginId: "codex", phase: PluginInstallPhase.completed);
      await _pump();
      expect(service.installProgress.value, isEmpty);
      // The terminal outcome does not itself refresh; the bridge's snapshot
      // invalidation does, exactly as for any other management change.
      expect(repository.loadCalls, 1);
      // This surface only watched the install, so it is not its outcome to
      // report — otherwise the metric would count surfaces, not installs.
      expect(reportedEvents, isEmpty);
    });

    test("reports the outcome only for an install this app started", () async {
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "one")))
        ..queueMutation(_success(_response(token: "one")));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      // An install another surface started is watched but never reported.
      connection.emitInstallProgress(pluginId: "opencode", phase: PluginInstallPhase.downloading, percent: 5);
      await _pump();
      connection.emitInstallProgress(pluginId: "opencode", phase: PluginInstallPhase.failed);
      await _pump();
      expect(reportedEvents, isEmpty);

      await service.command(
        pluginId: "codex",
        request: const PluginLifecycleCommandRequest.install(),
      );
      connection.emitInstallProgress(pluginId: "codex", phase: PluginInstallPhase.downloading, percent: 5);
      await _pump();
      connection.emitInstallProgress(pluginId: "codex", phase: PluginInstallPhase.failed);
      await _pump();

      // Bounded and identity-free: only the outcome crosses the wire.
      expect(reportedEvents.single, isA<HarnessInstallFinishedEvent>());
      expect(reportedEvents.single.parameters, {"outcome": "failed"});
      expect(reportedEvents.single.wireName, "harness_install_finished");
    });

    test("an install that settles before its command returns still reports once", () async {
      final mutation = Completer<PluginManagementMutationResult>();
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "one")))
        ..queueMutation(mutation.future);
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      final command = service.command(
        pluginId: "codex",
        request: const PluginLifecycleCommandRequest.install(),
      );
      // The row is busy from the tap, before any progress event arrives.
      await _pump();
      expect(service.installProgress.value.containsKey("codex"), isTrue);

      // A cached install can finish inside the request round trip.
      connection.emitInstallProgress(pluginId: "codex", phase: PluginInstallPhase.completed);
      await _pump();
      expect(reportedEvents, isEmpty);

      mutation.complete(_success(_response(token: "one")));
      await command;
      await _pump();

      expect(reportedEvents.single.parameters, {"outcome": "completed"});
      expect(service.installProgress.value, isEmpty);
    });

    test("the row stays busy from acceptance until the first progress event", () async {
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "one")))
        ..queueMutation(_success(_response(token: "one")));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      await service.command(
        pluginId: "codex",
        request: const PluginLifecycleCommandRequest.install(),
      );
      await _pump();

      // Accepted, but the bridge has not reported a phase yet: the harness must
      // still read as installing so the row cannot be tapped again.
      expect(service.installProgress.value.containsKey("codex"), isTrue);

      connection.emitInstallProgress(pluginId: "codex", phase: PluginInstallPhase.downloading, percent: 5);
      await _pump();
      expect(
        service.installProgress.value["codex"],
        const PluginInstallProgress(phase: PluginInstallPhase.downloading, percent: 5),
      );

      connection.emitInstallProgress(pluginId: "codex", phase: PluginInstallPhase.completed);
      await _pump();
      expect(service.installProgress.value, isEmpty);
    });

    test("a reconnect during an unresolved install command leaves no busy row", () async {
      final mutation = Completer<PluginManagementMutationResult>();
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "one")))
        ..queueMutation(mutation.future)
        ..queueLoad(_supported(_response(token: "two")));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      final command = service.command(
        pluginId: "codex",
        request: const PluginLifecycleCommandRequest.install(),
      );
      await _pump();
      expect(service.installProgress.value.containsKey("codex"), isTrue);

      connection.emitStatus(const ConnectionStatus.disconnected());
      await _pump();
      expect(service.installProgress.value, isEmpty);

      // The orphaned command resolving later must not resurrect the row.
      mutation.complete(_success(_response(token: "one")));
      await command;
      await _pump();

      expect(service.installProgress.value, isEmpty);
      expect(reportedEvents, isEmpty);
    });

    test("an uncertain install keeps the busy row and still reports its outcome", () async {
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "one")))
        ..queueMutation(const PluginManagementMutationResult.uncertain())
        ..queueLoad(_supported(_response(token: "two")));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      await service.command(
        pluginId: "codex",
        request: const PluginLifecycleCommandRequest.install(),
      );
      await _pump();

      // The command may still have reached the bridge, so Install must not
      // become tappable and start a second download.
      expect(service.installProgress.value.containsKey("codex"), isTrue);

      connection.emitInstallProgress(pluginId: "codex", phase: PluginInstallPhase.completed);
      await _pump();

      expect(service.installProgress.value, isEmpty);
      expect(reportedEvents.single.parameters, {"outcome": "completed"});
    });

    test("a rejected install command never claims a later install", () async {
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "one")))
        ..queueMutation(PluginManagementMutationResult.failure(error: ApiError.generic()));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);

      await service.command(
        pluginId: "codex",
        request: const PluginLifecycleCommandRequest.install(),
      );
      await _pump();

      // A rejected command must also release the busy row, or Install could
      // never be retried.
      expect(service.installProgress.value, isEmpty);

      // The bridge never accepted it, so a later install of the same harness
      // (started elsewhere) is not this app's outcome.
      connection.emitInstallProgress(pluginId: "codex", phase: PluginInstallPhase.downloading, percent: 5);
      await _pump();
      connection.emitInstallProgress(pluginId: "codex", phase: PluginInstallPhase.completed);
      await _pump();

      expect(reportedEvents, isEmpty);
    });

    test("a reconnect clears progress that belonged to the previous connection", () async {
      final repository = _FakePluginRepository()
        ..queueLoad(_supported(_response(token: "one")))
        ..queueLoad(_supported(_response(token: "two")));
      final connection = _FakeConnectionService(initialStatus: _connected);
      final service = PluginManagementService(
        pluginRepository: repository,
        connectionService: connection,
        productAnalyticsService: analytics,
      );
      addTearDown(() async {
        await service.onDispose();
        await connection.dispose();
      });
      await _waitFor(() => service.snapshots.hasValue);
      connection.emitInstallProgress(pluginId: "codex", phase: PluginInstallPhase.downloading, percent: 10);
      await _pump();
      expect(service.installProgress.value, isNotEmpty);

      connection.emitStatus(const ConnectionStatus.disconnected());
      await _pump();

      expect(service.installProgress.value, isEmpty);
    });
  });
}

const _config = ServerConnectionConfig(relayHost: "relay.example.com");
const _health = HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false);
const _connected = ConnectionStatus.connected(config: _config, health: _health);

PluginManagementResponse _response({
  required String token,
  String? bridgeId = "br_a",
  int timeout = 10,
}) {
  return PluginManagementResponse(
    snapshotToken: token,
    bridgeId: bridgeId,
    defaultPluginId: "one",
    defaultIdleTimeoutMins: timeout,
    plugins: const [],
  );
}

PluginManagementLoadResult _supported(PluginManagementResponse response) {
  return PluginManagementLoadResult.supported(response: response, refreshError: null);
}

PluginManagementMutationResult _success(PluginManagementResponse response) {
  return PluginManagementMutationResult.success(response: response);
}

PluginLifecycleConflict _conflict(List<PluginLifecycleConflictReason> reasons) {
  return PluginLifecycleConflict(
    pluginId: "one",
    reasons: reasons,
    current: const PluginManagementMetadata(
      setup: PluginSetupMetadata(
        id: "one",
        displayName: "One",
        state: PluginSetupState.ready,
        actionHint: null,
      ),
      runtimeState: PluginRuntimeState.dormant,
      workState: PluginManagementWorkState.idle,
      idleTimeoutMins: 10,
      hasIdleTimeoutOverride: false,
      managementCapabilities: {
        PluginManagementCapability.lifecycle,
        PluginManagementCapability.setupRefresh,
        PluginManagementCapability.idleTimeout,
      },
      actionHint: null,
    ),
  );
}

PluginManagementResponse _supportedResponse(PluginManagementService service) {
  return (service.snapshots.value as PluginManagementLoadResultSupported).response;
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await _pump();
  }
  throw StateError("condition was not reached");
}

class _FakePluginRepository implements PluginRepository {
  final Queue<Future<PluginManagementLoadResult>> _loads = Queue();
  final Queue<Future<PluginManagementMutationResult>> _mutations = Queue();
  int loadCalls = 0;
  int mutationCalls = 0;

  void queueLoad(FutureOr<PluginManagementLoadResult> result) {
    _loads.add(Future<PluginManagementLoadResult>.value(result));
  }

  void queueMutation(FutureOr<PluginManagementMutationResult> result) {
    _mutations.add(Future<PluginManagementMutationResult>.value(result));
  }

  @override
  Future<PluginManagementLoadResult> getManagement() {
    loadCalls++;
    if (_loads.isEmpty) throw StateError("No queued management load");
    return _loads.removeFirst();
  }

  @override
  Future<PluginManagementMutationResult> command({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
  }) {
    return _nextMutation();
  }

  @override
  Future<PluginManagementMutationResult> updateIdleTimeout({
    required PluginIdleTimeoutUpdateRequest request,
  }) {
    return _nextMutation();
  }

  Future<PluginManagementMutationResult> _nextMutation() {
    mutationCalls++;
    if (_mutations.isEmpty) throw StateError("No queued management mutation");
    return _mutations.removeFirst();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeConnectionService implements ConnectionService {
  _FakeConnectionService({required ConnectionStatus initialStatus}) : _statuses = BehaviorSubject.seeded(initialStatus);

  final BehaviorSubject<ConnectionStatus> _statuses;
  final StreamController<SseEvent> _events = StreamController.broadcast();
  final StreamController<void> _stale = StreamController.broadcast();

  @override
  ConnectionStatus get currentStatus => _statuses.value;

  @override
  ValueStream<ConnectionStatus> get status => _statuses.stream;

  @override
  Stream<SseEvent> get events => _events.stream;

  @override
  Stream<void> get dataMayBeStale => _stale.stream;

  void emitStatus(ConnectionStatus status) => _statuses.add(status);

  void emitStale() => _stale.add(null);

  void emitManagementChanged({required String snapshotToken}) {
    _events.add(
      SseEvent(
        data: SesoriSseEvent.pluginManagementChanged(snapshotToken: snapshotToken),
      ),
    );
  }

  void emitInstallProgress({
    required String pluginId,
    required PluginInstallPhase phase,
    int? percent,
  }) {
    _events.add(
      SseEvent(
        data: SesoriSseEvent.pluginInstallProgress(
          pluginId: pluginId,
          phase: phase,
          percent: percent,
          message: null,
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await Future.wait([_statuses.close(), _events.close(), _stale.close()]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
