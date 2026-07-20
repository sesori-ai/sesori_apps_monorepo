import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_management_result.dart";
import "package:sesori_dart_core/src/repositories/plugin_repository.dart";
import "package:sesori_dart_core/src/services/plugin_management_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/plugin_management_test_data.dart";

class MockPluginRepository extends Mock implements PluginRepository {}

class MockConnectionService extends Mock implements ConnectionService {}

const connectedStatus = ConnectionStatus.connected(
  config: ServerConnectionConfig(relayHost: "relay.example", authToken: "token"),
  health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: null),
);

Future<void> settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late MockPluginRepository repository;
  late MockConnectionService connectionService;
  late BehaviorSubject<ConnectionStatus> statuses;
  late StreamController<SseEvent> events;
  PluginManagementService? service;

  setUp(() {
    repository = MockPluginRepository();
    connectionService = MockConnectionService();
    statuses = BehaviorSubject.seeded(const ConnectionStatus.disconnected());
    events = StreamController<SseEvent>.broadcast();
    when(() => connectionService.currentStatus).thenAnswer((_) => statuses.value);
    when(() => connectionService.status).thenAnswer((_) => statuses.stream);
    when(() => connectionService.events).thenAnswer((_) => events.stream);
  });

  tearDown(() async {
    await service?.onDispose();
    await events.close();
    await statuses.close();
  });

  PluginManagementService build() {
    final created = PluginManagementService(
      pluginRepository: repository,
      connectionService: connectionService,
    );
    service = created;
    return created;
  }

  test("waits for a connection before the initial GET", () async {
    when(repository.getManagement).thenAnswer(
      (_) async => const PluginManagementLoadResult.supported(response: testPluginManagementResponse),
    );
    final current = build();

    await settle();
    verifyNever(repository.getManagement);

    statuses.add(connectedStatus);
    await expectLater(
      current.snapshots,
      emits(const PluginManagementLoadResult.supported(response: testPluginManagementResponse)),
    );
    verify(repository.getManagement).called(1);
  });

  test("connection and management SSE are symmetric staleness triggers without polling", () async {
    statuses.add(connectedStatus);
    var calls = 0;
    when(repository.getManagement).thenAnswer((_) async {
      calls++;
      return PluginManagementLoadResult.supported(
        response: testPluginManagementResponseAt(revision: calls),
      );
    });
    final current = build();
    await expectLater(
      current.snapshots,
      emits(PluginManagementLoadResult.supported(response: testPluginManagementResponseAt(revision: 1))),
    );

    events.add(
      SseEvent(
        data: const SesoriSseEvent.pluginManagementChanged(revision: 0),
        directory: null,
      ),
    );
    await untilCalled(repository.getManagement);
    await settle();
    expect(calls, 2);

    statuses.add(
      const ConnectionStatus.reconnecting(
        config: ServerConnectionConfig(relayHost: "relay", authToken: "t"),
      ),
    );
    await settle();
    statuses.add(connectedStatus);
    await untilCalled(repository.getManagement);
    await settle();
    expect(calls, 3);

    await settle();
    expect(calls, 3);
  });

  test("coalesces concurrent invalidations into one trailing refresh", () async {
    statuses.add(connectedStatus);
    final first = Completer<PluginManagementLoadResult>();
    var calls = 0;
    when(repository.getManagement).thenAnswer((_) {
      calls++;
      if (calls == 1) return first.future;
      return Future.value(
        PluginManagementLoadResult.supported(response: testPluginManagementResponseAt(revision: 2)),
      );
    });
    final current = build();

    final refreshA = current.refresh();
    final refreshB = current.refresh();
    events.add(
      SseEvent(
        data: const SesoriSseEvent.pluginManagementChanged(revision: 99),
        directory: null,
      ),
    );
    first.complete(const PluginManagementLoadResult.supported(response: testPluginManagementResponse));
    await Future.wait([refreshA, refreshB]);
    await settle();

    expect(calls, 2);
    expect(
      current.snapshots.value,
      PluginManagementLoadResult.supported(response: testPluginManagementResponseAt(revision: 2)),
    );
  });

  test("failed refresh remains stale but waits for another trigger", () async {
    statuses.add(connectedStatus);
    final failure = ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null);
    var calls = 0;
    when(repository.getManagement).thenAnswer((_) async {
      calls++;
      return calls == 1
          ? PluginManagementLoadResult.failure(error: failure)
          : const PluginManagementLoadResult.supported(response: testPluginManagementResponse);
    });
    final current = build();
    await expectLater(current.snapshots, emits(PluginManagementLoadResult.failure(error: failure)));

    await settle();
    expect(calls, 1);

    final supported = expectLater(
      current.snapshots,
      emitsThrough(const PluginManagementLoadResult.supported(response: testPluginManagementResponse)),
    );
    events.add(
      SseEvent(
        data: const SesoriSseEvent.pluginManagementChanged(revision: 2),
        directory: null,
      ),
    );
    await supported;
    expect(calls, 2);
  });

  test("applies only non-older revisions from refreshes and mutations", () async {
    statuses.add(connectedStatus);
    when(repository.getManagement).thenAnswer(
      (_) async => PluginManagementLoadResult.supported(
        response: testPluginManagementResponseAt(revision: 3),
      ),
    );
    final current = build();
    await expectLater(
      current.snapshots,
      emits(PluginManagementLoadResult.supported(response: testPluginManagementResponseAt(revision: 3))),
    );

    when(repository.getManagement).thenAnswer(
      (_) async => PluginManagementLoadResult.supported(
        response: testPluginManagementResponseAt(revision: 2),
      ),
    );
    await current.refresh();
    expect(
      current.snapshots.value,
      PluginManagementLoadResult.supported(response: testPluginManagementResponseAt(revision: 3)),
    );

    const request = PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe);
    when(() => repository.command(pluginId: "plugin-a", request: request)).thenAnswer(
      (_) async => PluginManagementMutationResult.success(
        response: testPluginManagementResponseAt(revision: 2),
      ),
    );
    expect(
      await current.command(pluginId: "plugin-a", request: request),
      PluginManagementMutationResult.success(response: testPluginManagementResponseAt(revision: 3)),
    );

    when(() => repository.command(pluginId: "plugin-a", request: request)).thenAnswer(
      (_) async => PluginManagementMutationResult.success(
        response: testPluginManagementResponseAt(revision: 4),
      ),
    );
    expect(
      await current.command(pluginId: "plugin-a", request: request),
      PluginManagementMutationResult.success(response: testPluginManagementResponseAt(revision: 4)),
    );
    expect(
      current.snapshots.value,
      PluginManagementLoadResult.supported(response: testPluginManagementResponseAt(revision: 4)),
    );
  });

  test("an in-flight refresh failure cannot overwrite a successful mutation", () async {
    statuses.add(connectedStatus);
    when(repository.getManagement).thenAnswer(
      (_) async => const PluginManagementLoadResult.supported(response: testPluginManagementResponse),
    );
    final current = build();
    await expectLater(
      current.snapshots,
      emits(const PluginManagementLoadResult.supported(response: testPluginManagementResponse)),
    );

    final refreshResult = Completer<PluginManagementLoadResult>();
    when(repository.getManagement).thenAnswer((_) => refreshResult.future);
    final refresh = current.refresh();
    const request = PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe);
    when(() => repository.command(pluginId: "plugin-a", request: request)).thenAnswer(
      (_) async => PluginManagementMutationResult.success(
        response: testPluginManagementResponseAt(revision: 3),
      ),
    );
    await current.command(pluginId: "plugin-a", request: request);
    refreshResult.complete(
      PluginManagementLoadResult.failure(
        error: ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null),
      ),
    );
    await refresh;

    expect(
      current.snapshots.value,
      PluginManagementLoadResult.supported(response: testPluginManagementResponseAt(revision: 3)),
    );
  });

  test("dispose cancels connection and event subscriptions", () async {
    final current = build();
    await current.onDispose();

    statuses.add(connectedStatus);
    events.add(
      SseEvent(
        data: const SesoriSseEvent.pluginManagementChanged(revision: 1),
        directory: null,
      ),
    );
    await settle();

    verifyNever(repository.getManagement);
  });
}
