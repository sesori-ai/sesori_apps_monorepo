import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../capabilities/server_connection/server_connection_config.dart";
import "../logging/logging.dart";
import "../platform/url_launcher.dart";
import "../repositories/mcp_repository.dart";
import "../repositories/models/mcp_action_response.dart";
import "../repositories/models/mcp_read_result.dart";
import "models/mcp_action_client_state.dart";
import "models/mcp_inventory_state.dart";

/// One view's inventory lifecycle. Factory DI keeps simultaneous views independent.
@injectable
class McpService({
  required final McpRepository _repository,
  required final ConnectionService _connectionService,
  required final UrlLauncher _urlLauncher,
}) {
  this {
    _subscriptions
      ..add(_connectionService.status.listen(_onConnectionStatus))
      ..add(
        _connectionService.events.listen((event) {
          if (event.data case SesoriMcpInventoryChanged(:final pluginId, :final scope)) {
            final request = _request;
            if (request != null &&
                request.pluginId == pluginId &&
                (scope is McpHarnessScope || request.scope == scope)) {
              _staleVersion++;
              unawaited(refresh());
            }
          }
        }),
      )
      ..add(
        _connectionService.dataMayBeStale.listen((_) {
          _staleVersion++;
          unawaited(refresh());
        }),
      );
  }

  final BehaviorSubject<McpInventoryState> _state = BehaviorSubject.seeded(const McpInventoryInitial());
  final BehaviorSubject<McpActionClientState> _actions = BehaviorSubject.seeded(const McpActionsReadOnly());
  final CompositeSubscription _subscriptions = CompositeSubscription();
  ConnectionStatus _connection = _connectionService.currentStatus;
  McpInventoryRequest? _request;
  int _generation = 0;
  int? _readingGeneration;
  int _staleVersion = 0;

  ValueStream<McpInventoryState> get states => _state.stream;
  McpInventoryState get currentState => _state.value;
  ValueStream<McpActionClientState> get actions => _actions.stream;
  McpActionClientState get currentAction => _actions.value;

  void bind({required McpInventoryRequest request, required bool mutationsAllowed}) {
    if (_state.isClosed || request == _request) return;
    _generation++;
    _request = request;
    _actions.add(mutationsAllowed ? const McpActionIdle() : const McpActionsReadOnly());
    _state.add(const McpInventoryWaitingForConnection());
    unawaited(refresh());
  }

  Future<void> executeAction({required McpEntryAction action}) async {
    final request = _request;
    if (_actions.isClosed ||
        request == null ||
        currentAction is McpActionsReadOnly ||
        currentAction is McpActionPending) {
      return;
    }
    if (_connection is! ConnectionConnected) {
      _actions.add(const McpActionOffline());
      return;
    }
    final generation = _generation;
    final staleVersion = _staleVersion;
    final operation = McpEntryActionRequest(pluginId: request.pluginId, action: action);
    _actions.add(McpActionPending(request: operation));
    final response = await _repository.executeAction(request: operation);
    if (_actions.isClosed || generation != _generation) return;
    switch (response) {
      case McpActionRequestFailed(:final cause):
        if (action is McpConnectorSetupEntryAction) {
          loge(
            "MCP connector setup resolution failed for ${operation.pluginId} / ${action.offerTarget.toString()}",
            cause,
          );
          _actions.add(McpConnectorSetupFailed(request: operation));
          return;
        }
        _actions.add(McpActionUncertain(request: operation, cause: cause));
        _staleVersion++;
        unawaited(refresh());
      case McpActionReceived(:final result):
        if (result is McpExternalSetup) {
          final destination = action is McpConnectorSetupEntryAction
              ? _repository.connectorSetupDestination(result: result)
              : null;
          if (destination == null) {
            _actions.add(McpActionReceivedState(request: operation, result: const McpActionFailed()));
            return;
          }
          var opened = false;
          try {
            opened = await _urlLauncher.launch(destination);
          } on Object catch (error, stackTrace) {
            loge(
              "MCP connector setup browser launch failed",
              ExternalLinkLaunchFailure(url: destination, innerError: error),
              stackTrace,
            );
          }
          if (_actions.isClosed || generation != _generation) return;
          _actions.add(
            opened ? McpConnectorSetupOpened(request: operation) : McpConnectorSetupFailed(request: operation),
          );
          return;
        }
        _actions.add(McpActionReceivedState(request: operation, result: result));
        if (result case McpActionCompleted(:final inventory)) {
          // The action's native read supersedes any earlier inventory request.
          _generation++;
          _readingGeneration = null;
          final previous = currentState;
          _state.add(switch (inventory) {
            McpInventoryUnavailable()
                when previous is McpInventoryReady && previous.inventory is McpInventorySnapshot =>
              McpInventoryReady(
                inventory: previous.inventory,
                refresh: McpInventoryRefreshUnavailable(cause: inventory),
              ),
            McpInventoryUnknown() when previous is McpInventoryReady && previous.inventory is McpInventorySnapshot =>
              McpInventoryReady(
                inventory: previous.inventory,
                refresh: const McpInventoryRefreshUnrecognized(),
              ),
            McpInventoryUnknown() => const McpInventoryUnrecognized(),
            McpInventorySnapshot() || McpInventoryUnavailable() => McpInventoryReady(
              inventory: inventory,
              refresh: const McpInventoryRefreshIdle(),
            ),
          });
          if (_staleVersion > staleVersion) unawaited(refresh());
        }
    }
  }

  Future<void> refresh() async {
    final request = _request;
    if (_state.isClosed ||
        request == null ||
        _connection is! ConnectionConnected ||
        _readingGeneration == _generation) {
      return;
    }
    final generation = _generation;
    final staleVersion = _staleVersion;
    _readingGeneration = generation;
    if (currentAction
        case McpConnectorSetupOpened() ||
            McpConnectorSetupFailed() ||
            McpActionReceivedState(request: McpEntryActionRequest(action: McpConnectorSetupEntryAction()))) {
      _actions.add(const McpActionIdle());
    }
    final previous = currentState;
    _state.add(switch (previous) {
      McpInventoryReady(:final inventory) => McpInventoryReady(
        inventory: inventory,
        refresh: const McpInventoryRefreshing(),
      ),
      McpInventoryInitial() ||
      McpInventoryWaitingForConnection() ||
      McpInventoryLoading() ||
      McpInventoryUnrecognized() ||
      McpInventoryNotFound() ||
      McpInventoryReadFailed() ||
      McpInventoryFailed() => const McpInventoryLoading(),
    });
    final result = await _repository.getInventory(request: request);
    if (_state.isClosed || generation != _generation) return;
    _readingGeneration = null;
    _state.add(switch (result) {
      McpReadSuccess(:final McpInventoryUnavailable inventory)
          when previous is McpInventoryReady && previous.inventory is McpInventorySnapshot =>
        McpInventoryReady(
          inventory: previous.inventory,
          refresh: McpInventoryRefreshUnavailable(cause: inventory),
        ),
      McpReadSuccess(:final inventory) => McpInventoryReady(
        inventory: inventory,
        refresh: const McpInventoryRefreshIdle(),
      ),
      McpReadNotFound(:final cause) => switch (previous) {
        McpInventoryReady(:final inventory) => McpInventoryReady(
          inventory: inventory,
          refresh: McpInventoryRefreshNotFound(cause: cause),
        ),
        McpInventoryInitial() ||
        McpInventoryWaitingForConnection() ||
        McpInventoryLoading() ||
        McpInventoryUnrecognized() ||
        McpInventoryNotFound() ||
        McpInventoryReadFailed() ||
        McpInventoryFailed() => McpInventoryNotFound(cause: cause),
      },
      McpReadUnrecognized() => switch (previous) {
        McpInventoryReady(:final inventory) => McpInventoryReady(
          inventory: inventory,
          refresh: const McpInventoryRefreshUnrecognized(),
        ),
        McpInventoryInitial() ||
        McpInventoryWaitingForConnection() ||
        McpInventoryLoading() ||
        McpInventoryUnrecognized() ||
        McpInventoryNotFound() ||
        McpInventoryReadFailed() ||
        McpInventoryFailed() => const McpInventoryUnrecognized(),
      },
      McpReadInventoryFailed(:final cause) => switch (previous) {
        McpInventoryReady(:final inventory) => McpInventoryReady(
          inventory: inventory,
          refresh: McpInventoryRefreshUnavailable(cause: cause),
        ),
        McpInventoryInitial() ||
        McpInventoryWaitingForConnection() ||
        McpInventoryLoading() ||
        McpInventoryUnrecognized() ||
        McpInventoryNotFound() ||
        McpInventoryReadFailed() ||
        McpInventoryFailed() => McpInventoryReadFailed(cause: cause),
      },
      McpReadFailed(:final cause) => switch (previous) {
        McpInventoryReady(:final inventory) => McpInventoryReady(
          inventory: inventory,
          refresh: McpInventoryRefreshFailed(cause: cause),
        ),
        McpInventoryInitial() ||
        McpInventoryWaitingForConnection() ||
        McpInventoryLoading() ||
        McpInventoryUnrecognized() ||
        McpInventoryNotFound() ||
        McpInventoryReadFailed() ||
        McpInventoryFailed() => McpInventoryFailed(cause: cause),
      },
    });
    // A signal received during the read still needs its own authoritative result.
    // A failed result remains stale in state; reconnect or explicit refresh re-arms
    // the read without a second stale signal. Do not poll a failed native process.
    if (_staleVersion > staleVersion) unawaited(refresh());
  }

  void _onConnectionStatus(ConnectionStatus next) {
    if (_state.isClosed) return;
    final oldConfig = _config(status: _connection);
    final nextConfig = _config(status: next);
    final wasConnected = _connection is ConnectionConnected;
    final isConnected = next is ConnectionConnected;
    _connection = next;
    if (oldConfig != nextConfig) {
      _generation++;
      if (currentAction is! McpActionsReadOnly) _actions.add(const McpActionIdle());
      if (_request != null) _state.add(const McpInventoryWaitingForConnection());
    } else if (wasConnected && !isConnected) {
      _generation++;
      if (currentAction is! McpActionsReadOnly) _actions.add(const McpActionOffline());
      _state.add(switch (currentState) {
        McpInventoryReady(:final inventory) => McpInventoryReady(
          inventory: inventory,
          refresh: const McpInventoryRefreshOffline(),
        ),
        McpInventoryInitial() ||
        McpInventoryWaitingForConnection() ||
        McpInventoryLoading() ||
        McpInventoryUnrecognized() ||
        McpInventoryNotFound() ||
        McpInventoryReadFailed() ||
        McpInventoryFailed() => const McpInventoryWaitingForConnection(),
      });
    }
    if (isConnected && (!wasConnected || oldConfig != nextConfig)) {
      if (currentAction is McpActionOffline) _actions.add(const McpActionIdle());
      unawaited(refresh());
    }
  }

  ServerConnectionConfig? _config({required ConnectionStatus status}) => switch (status) {
    ConnectionDisconnected() => null,
    ConnectionConnected(:final config) ||
    ConnectionReconnecting(:final config) ||
    ConnectionLost(:final config) ||
    ConnectionBridgeOffline(:final config) => config,
  };

  Future<void> dispose() async {
    _generation++;
    await _subscriptions.cancel();
    await Future.wait([_state.close(), _actions.close()]);
  }
}
