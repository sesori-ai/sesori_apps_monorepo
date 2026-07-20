import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../capabilities/server_connection/models/sse_event.dart";
import "../repositories/models/plugin_management_result.dart";
import "../repositories/plugin_repository.dart";

typedef _MutationFence = ({int connectionEpoch, int staleGeneration});

@lazySingleton
class PluginManagementService with Disposable {
  final PluginRepository _pluginRepository;
  final BehaviorSubject<PluginManagementLoadResult> _snapshots = BehaviorSubject();
  final CompositeSubscription _subscriptions = CompositeSubscription();

  Future<void>? _refreshTail;
  late bool _isConnected;
  bool _disposed = false;
  int _connectionEpoch = 0;
  int _staleGeneration = 0;
  int _appliedStaleGeneration = 0;
  int _lastAttemptedStaleGeneration = 0;
  int? _responseEpoch;
  PluginManagementResponse? _response;

  PluginManagementService({
    required PluginRepository pluginRepository,
    required ConnectionService connectionService,
  }) : _pluginRepository = pluginRepository {
    _isConnected = connectionService.currentStatus is ConnectionConnected;
    _subscriptions.add(connectionService.status.listen(_onConnectionStatus));
    _subscriptions.add(connectionService.events.listen(_onEvent));
    if (_isConnected) _markStale();
  }

  ValueStream<PluginManagementLoadResult> get snapshots => _snapshots.stream;

  Future<void> refresh() {
    _markStale();
    return _refreshTail ?? Future<void>.value();
  }

  Future<PluginManagementMutationResult> command({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
  }) async {
    final fence = _captureMutationFence();
    final result = await _pluginRepository.command(pluginId: pluginId, request: request);
    return _acceptMutationResult(result: result, fence: fence);
  }

  Future<PluginManagementMutationResult> updateIdleTimeout({
    required PluginIdleTimeoutUpdateRequest request,
  }) async {
    final fence = _captureMutationFence();
    final result = await _pluginRepository.updateIdleTimeout(request: request);
    return _acceptMutationResult(result: result, fence: fence);
  }

  void _markStale() {
    if (_disposed) return;
    _staleGeneration++;
    _startRefreshIfNeeded();
  }

  void _startRefreshIfNeeded() {
    if (_disposed || !_isConnected || _refreshTail != null) return;
    late final Future<void> tail;
    tail = _drainRefreshes().whenComplete(() {
      if (identical(_refreshTail, tail)) _refreshTail = null;
      if (_isConnected && _staleGeneration > _lastAttemptedStaleGeneration) {
        _startRefreshIfNeeded();
      }
    });
    _refreshTail = tail;
  }

  Future<void> _drainRefreshes() async {
    while (!_disposed && _isConnected && _appliedStaleGeneration < _staleGeneration) {
      final targetGeneration = _staleGeneration;
      final requestEpoch = _connectionEpoch;
      _lastAttemptedStaleGeneration = targetGeneration;

      final result = await _pluginRepository.getManagement();
      if (_disposed) return;
      if (!_isConnected) return;
      if (requestEpoch != _connectionEpoch) {
        if (_staleGeneration > targetGeneration) continue;
        return;
      }
      if (targetGeneration <= _appliedStaleGeneration) {
        if (_staleGeneration > _appliedStaleGeneration) continue;
        return;
      }

      final applied = _applyLoadResult(result);
      if (applied) _consumeStalenessThrough(targetGeneration);
      if (_appliedStaleGeneration >= _staleGeneration) return;
      if (_staleGeneration > targetGeneration) continue;

      // A failed or older response remains stale, but waits for a new trigger
      // instead of turning the refresh tail into polling.
      return;
    }
  }

  bool _applyLoadResult(PluginManagementLoadResult result) {
    return switch (result) {
      PluginManagementSupported(:final response) => _publishSupported(response),
      PluginManagementUnsupported() => _publishUnsupported(),
      PluginManagementLoadFailure() => _publishFailure(result),
    };
  }

  PluginManagementMutationResult _acceptMutationResult({
    required PluginManagementMutationResult result,
    required _MutationFence fence,
  }) {
    if (result is! PluginManagementMutationSuccess) return result;
    if (_disposed || fence.connectionEpoch != _connectionEpoch) {
      _markStale();
      return PluginManagementMutationResult.failure(error: ApiError.generic());
    }

    if (_publishSupported(result.response)) {
      _consumeStalenessThrough(fence.staleGeneration);
      return result;
    }

    final current = _currentResponse;
    return current == null ? result : PluginManagementMutationResult.success(response: current);
  }

  bool _publishSupported(PluginManagementResponse response) {
    final current = _currentResponse;
    if (current != null && response.revision < current.revision) return false;

    _response = response;
    _responseEpoch = _connectionEpoch;
    _snapshots.add(PluginManagementLoadResult.supported(response: response));
    return true;
  }

  bool _publishUnsupported() {
    _response = null;
    _responseEpoch = _connectionEpoch;
    _snapshots.add(const PluginManagementLoadResult.unsupported());
    return true;
  }

  bool _publishFailure(PluginManagementLoadFailure failure) {
    _snapshots.add(failure);
    return false;
  }

  PluginManagementResponse? get _currentResponse => _responseEpoch == _connectionEpoch ? _response : null;

  void _consumeStalenessThrough(int generation) {
    if (generation > _appliedStaleGeneration) _appliedStaleGeneration = generation;
  }

  _MutationFence _captureMutationFence() => (
    connectionEpoch: _connectionEpoch,
    staleGeneration: _staleGeneration,
  );

  void _onEvent(SseEvent event) {
    if (event.data is SesoriPluginManagementChanged) _markStale();
  }

  void _onConnectionStatus(ConnectionStatus status) {
    final isConnected = status is ConnectionConnected;
    if (isConnected == _isConnected) return;

    _isConnected = isConnected;
    _connectionEpoch++;
    if (isConnected) _markStale();
  }

  @override
  Future<void> onDispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscriptions.dispose();
    await _refreshTail;
    await _snapshots.close();
  }
}
