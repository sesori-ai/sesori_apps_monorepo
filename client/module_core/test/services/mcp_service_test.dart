import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/repositories/mcp_repository.dart";
import "package:sesori_dart_core/src/repositories/models/mcp_read_result.dart";
import "package:sesori_dart_core/src/services/mcp_service.dart";
import "package:sesori_dart_core/src/services/models/mcp_inventory_state.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _request = McpInventoryRequest(
  pluginId: "fixture",
  scope: McpSessionScope(sessionId: "session-a"),
);
const _config = ServerConnectionConfig(relayHost: "wss://fixture.test/a", authToken: "fixture-a", bridgeId: null);
const _health = HealthResponse(healthy: true, version: "1.9.1", filesystemAccessDegraded: false);

void main() {
  late _Connection connection;
  late _Repository repository;
  late McpService service;
  setUp(() {
    connection = _Connection();
    repository = _Repository();
    service = McpService(repository: repository, connectionService: connection);
  });
  tearDown(() async {
    await service.dispose();
    await connection.dispose();
  });

  Future<McpInventoryReady> load() async {
    service.bind(request: _request);
    repository.pending.first.complete(
      McpReadSuccess(
        inventory: _snapshot(scope: _request.scope, name: "Fixture"),
      ),
    );
    return await service.states.firstWhere((state) => state is McpInventoryReady) as McpInventoryReady;
  }

  test("refresh failure retains the readable snapshot and original error", () async {
    final original = await load();
    final refresh = service.refresh();
    expect((service.currentState as McpInventoryReady).inventory, same(original.inventory));
    expect((service.currentState as McpInventoryReady).refresh, isA<McpInventoryRefreshing>());
    final cause = ApiError.generic();
    repository.pending.last.complete(McpReadFailed(cause: cause));
    await refresh;
    final failed = service.currentState as McpInventoryReady;
    expect(failed.inventory, same(original.inventory));
    expect((failed.refresh as McpInventoryRefreshFailed).cause, same(cause));
  });

  test("harness credential changes invalidate the selected session inventory", () async {
    await load();
    connection.eventController.add(
      SseEvent(
        data: const SesoriMcpInventoryChanged(pluginId: "fixture", scope: McpHarnessScope()),
      ),
    );
    await _pump();
    expect(repository.requests, hasLength(2));
    repository.pending.last.complete(
      McpReadSuccess(
        inventory: _snapshot(scope: _request.scope, name: "Reauthorized"),
      ),
    );
    await _pump();
  });

  test("native mutation invalidation refreshes only the selected plugin and scope", () async {
    await load();
    for (final event in [
      SesoriMcpInventoryChanged(pluginId: "other", scope: _request.scope),
      const SesoriMcpInventoryChanged(
        pluginId: "fixture",
        scope: McpSessionScope(sessionId: "other-session"),
      ),
    ]) {
      connection.eventController.add(SseEvent(data: event));
    }
    await _pump();
    expect(repository.requests, hasLength(1));
    connection.eventController.add(
      SseEvent(
        data: SesoriMcpInventoryChanged(pluginId: "fixture", scope: _request.scope),
      ),
    );
    await _pump();
    expect(repository.requests, hasLength(2));
    repository.pending.last.complete(
      McpReadSuccess(
        inventory: _snapshot(scope: _request.scope, name: "Updated"),
      ),
    );
    await _pump();
    final state = service.currentState as McpInventoryReady;
    expect(
      (state.inventory as McpInventorySnapshot).entries.single,
      isA<McpServerSnapshot>().having((s) => s.name, "name", "Updated"),
    );
  });

  test("a stopped integration retains last details with an unavailable refresh state", () async {
    final original = await load();
    final refresh = service.refresh();
    repository.pending.last.complete(
      const McpReadSuccess(
        inventory: McpInventoryUnavailable(
          scope: McpSessionScope(sessionId: "session-a"),
          reason: McpInventoryUnavailableReason.pluginInactive,
          message: "Integration inactive",
        ),
      ),
    );
    await refresh;
    final state = service.currentState as McpInventoryReady;
    expect(state.inventory, same(original.inventory));
    expect(
      (state.refresh as McpInventoryRefreshUnavailable).cause.reason,
      McpInventoryUnavailableReason.pluginInactive,
    );
  });

  test("a native read failure preserves details as an unavailable refresh", () async {
    final original = await load();
    final refresh = service.refresh();
    const cause = McpInventoryUnavailable(
      scope: McpSessionScope(sessionId: "session-a"),
      reason: McpInventoryUnavailableReason.readFailed,
      message: "Refresh to try again",
    );
    repository.pending.last.complete(const McpReadInventoryFailed(cause: cause));
    await refresh;
    final state = service.currentState as McpInventoryReady;
    expect(state.inventory, same(original.inventory));
    expect((state.refresh as McpInventoryRefreshUnavailable).cause, same(cause));
  });

  test("blocked staleness waits for connection without querying or polling", () async {
    connection.statuses.add(const ConnectionDisconnected());
    await _pump();
    service.bind(request: _request);
    connection.stale.add(null);
    connection.stale.add(null);
    await _pump();
    expect(repository.pending, isEmpty);
    expect(service.currentState, isA<McpInventoryWaitingForConnection>());
    connection.statuses.add(const ConnectionConnected(config: _config, health: _health));
    await _pump();
    expect(repository.pending, hasLength(1));
    repository.pending.single.complete(
      McpReadSuccess(
        inventory: _snapshot(scope: _request.scope, name: "Connected"),
      ),
    );
    await service.states.firstWhere((state) => state is McpInventoryReady);
    await _pump();
    expect(repository.pending, hasLength(1));
  });

  test("a changed scope fences an older read", () async {
    service.bind(request: _request);
    const next = McpInventoryRequest(
      pluginId: "fixture",
      scope: McpSessionScope(sessionId: "session-b"),
    );
    service.bind(request: next);
    expect(repository.requests, [_request, next]);
    repository.pending.first.complete(
      McpReadSuccess(
        inventory: _snapshot(scope: _request.scope, name: "Old"),
      ),
    );
    await repository.pending.first.future;
    expect(service.currentState, isA<McpInventoryLoading>());
    repository.pending.last.complete(
      McpReadSuccess(
        inventory: _snapshot(scope: next.scope, name: "New"),
      ),
    );
    final state = await service.states.firstWhere((state) => state is McpInventoryReady) as McpInventoryReady;
    expect((state.inventory as McpInventorySnapshot).scope, next.scope);
  });

  test("reconnect with the same configuration preserves details and fences the old refresh", () async {
    final original = await load();
    final refresh = service.refresh();
    connection.statuses.add(const ConnectionReconnecting(config: _config));
    await _pump();
    final offline = service.currentState as McpInventoryReady;
    expect(offline.inventory, same(original.inventory));
    expect(offline.refresh, isA<McpInventoryRefreshOffline>());
    repository.pending[1].complete(
      McpReadSuccess(
        inventory: _snapshot(scope: _request.scope, name: "Old refresh"),
      ),
    );
    await refresh;
    expect((service.currentState as McpInventoryReady).refresh, isA<McpInventoryRefreshOffline>());
    connection.statuses.add(const ConnectionConnected(config: _config, health: _health));
    await _pump();
    expect(repository.pending, hasLength(3));
    expect((service.currentState as McpInventoryReady).inventory, same(original.inventory));
    repository.pending.last.complete(
      McpReadSuccess(
        inventory: _snapshot(scope: _request.scope, name: "Refreshed"),
      ),
    );
    final state = await service.states.firstWhere(
      (state) => state is McpInventoryReady && state.refresh is McpInventoryRefreshIdle,
    ) as McpInventoryReady;
    expect(
      (state.inventory as McpInventorySnapshot).entries.single,
      isA<McpServerSnapshot>().having((server) => server.name, "name", "Refreshed"),
    );
  });

  test("a changed connection configuration clears old details before reading its inventory", () async {
    await load();
    final refresh = service.refresh();
    const next = ServerConnectionConfig(relayHost: "wss://fixture.test/b", authToken: "fixture-b", bridgeId: null);
    connection.statuses.add(const ConnectionReconnecting(config: next));
    await _pump();
    expect(service.currentState, isA<McpInventoryWaitingForConnection>());
    connection.statuses.add(const ConnectionConnected(config: next, health: _health));
    await _pump();
    expect(service.currentState, isA<McpInventoryLoading>());
    repository.pending[1].complete(
      McpReadSuccess(
        inventory: _snapshot(scope: _request.scope, name: "Old bridge"),
      ),
    );
    await refresh;
    expect(service.currentState, isA<McpInventoryLoading>());
    repository.pending.last.complete(
      McpReadSuccess(
        inventory: _snapshot(scope: _request.scope, name: "New bridge"),
      ),
    );
    final state = await service.states.firstWhere((state) => state is McpInventoryReady) as McpInventoryReady;
    expect(
      (state.inventory as McpInventorySnapshot).entries.single,
      isA<McpServerSnapshot>().having((server) => server.name, "name", "New bridge"),
    );
  });

  test("a newer staleness signal survives an in-flight failure", () async {
    await load();
    final refresh = service.refresh();
    connection.stale.add(null);
    await _pump();
    expect(repository.pending, hasLength(2));
    repository.pending[1].complete(McpReadFailed(cause: ApiError.generic()));
    await refresh;
    expect(repository.pending, hasLength(3));
    repository.pending.last.complete(
      McpReadSuccess(
        inventory: _snapshot(scope: _request.scope, name: "After signal"),
      ),
    );
    await service.states.firstWhere((state) => state is McpInventoryReady && state.refresh is McpInventoryRefreshIdle);
    await _pump();
    expect(repository.pending, hasLength(3));
  });

  test("404 on refresh retains details and its distinct original cause", () async {
    final original = await load();
    final refresh = service.refresh();
    final cause = NonSuccessCodeError(errorCode: 404, rawErrorString: "Missing route or session");
    repository.pending.last.complete(McpReadNotFound(cause: cause));
    await refresh;
    final state = service.currentState as McpInventoryReady;
    expect(state.inventory, same(original.inventory));
    expect((state.refresh as McpInventoryRefreshNotFound).cause, same(cause));
  });

  test("initial 404 remains distinct from a retained refresh failure", () async {
    service.bind(request: _request);
    final cause = NonSuccessCodeError(errorCode: 404, rawErrorString: "Missing route or session");
    repository.pending.last.complete(McpReadNotFound(cause: cause));
    final state = await service.states.firstWhere((state) => state is McpInventoryNotFound) as McpInventoryNotFound;
    expect(state.cause, same(cause));
  });

  test("unrecognized initial inventory is not a ready snapshot", () async {
    service.bind(request: _request);
    repository.pending.last.complete(const McpReadUnrecognized());
    await service.states.firstWhere((state) => state is McpInventoryUnrecognized);
    expect(service.currentState, isNot(isA<McpInventoryReady>()));
  });

  test("unrecognized refresh preserves the last readable snapshot", () async {
    final original = await load();
    final refresh = service.refresh();
    repository.pending.last.complete(const McpReadUnrecognized());
    await refresh;
    final state = service.currentState as McpInventoryReady;
    expect(state.inventory, same(original.inventory));
    expect(state.refresh, isA<McpInventoryRefreshUnrecognized>());
  });

  for (final failure in [
    McpReadFailed(cause: ApiError.generic()),
    const McpReadInventoryFailed(
      cause: McpInventoryUnavailable(
        scope: McpSessionScope(sessionId: "session-a"),
        reason: McpInventoryUnavailableReason.readFailed,
        message: "Read failed",
      ),
    ),
  ]) {
    test("one failed stale read re-arms on reconnect without a second signal: ${failure.runtimeType}", () async {
      final original = await load();
      connection.stale.add(null);
      await _pump();
      repository.pending.last.complete(failure);
      await _pump();
      expect(repository.pending, hasLength(2));
      expect((service.currentState as McpInventoryReady).inventory, same(original.inventory));
      connection.statuses.add(const ConnectionReconnecting(config: _config));
      await _pump();
      connection.statuses.add(const ConnectionConnected(config: _config, health: _health));
      await _pump();
      expect(repository.pending, hasLength(3));
      repository.pending.last.complete(McpReadSuccess(inventory: original.inventory));
      await service.states.firstWhere(
        (state) => state is McpInventoryReady && state.refresh is McpInventoryRefreshIdle,
      );
      await _pump();
      expect(repository.pending, hasLength(3));
    });
  }

  test("closing the view fences a pending read", () async {
    final other = McpService(repository: repository, connectionService: connection);
    other.bind(request: _request);
    await other.dispose();
    repository.pending.first.complete(
      McpReadSuccess(
        inventory: _snapshot(scope: _request.scope, name: "Late"),
      ),
    );
    await repository.pending.first.future;
    await _pump();
    expect(other.currentState, isA<McpInventoryLoading>());
  });
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

McpInventorySnapshot _snapshot({required McpScope scope, required String name}) => McpInventorySnapshot(
  scope: scope,
  servers: const McpCatalogAvailable(),
  connectors: const McpCatalogNotSupported(),
  entries: [
    McpServerSnapshot(
      actions: const [],
      serverTarget: McpServerTarget(scope: scope, serverKey: "fixture"),
      name: name,
      description: null,
      endpointOrigin: null,
      configuration: null,
      authorization: McpAuthorizationState.unknown,
      connection: const McpConnectionStatus(phase: McpConnectionPhase.connected),
      tools: const McpToolsAvailable(tools: []),
    ),
  ],
);

class _Repository() implements McpRepository {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
  final List<McpInventoryRequest> requests = [];
  final List<Completer<McpReadResult>> pending = [];
  @override
  Future<McpReadResult> getInventory({required McpInventoryRequest request}) {
    requests.add(request);
    final result = Completer<McpReadResult>();
    pending.add(result);
    return result.future;
  }
}

class _Connection() implements ConnectionService {
  final BehaviorSubject<ConnectionStatus> statuses = BehaviorSubject.seeded(
    const ConnectionConnected(config: _config, health: _health),
  );
  final StreamController<void> stale = StreamController.broadcast();
  final StreamController<SseEvent> eventController = StreamController.broadcast();
  @override
  Stream<SseEvent> get events => eventController.stream;
  @override
  ConnectionStatus get currentStatus => statuses.value;
  @override
  ValueStream<ConnectionStatus> get status => statuses.stream;
  @override
  Stream<void> get dataMayBeStale => stale.stream;
  @override
  Future<void> dispose() async {
    await statuses.close();
    await stale.close();
    await eventController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
