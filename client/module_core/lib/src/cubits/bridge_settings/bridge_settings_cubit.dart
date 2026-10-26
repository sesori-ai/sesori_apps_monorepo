import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../repositories/models/bridge_settings_result.dart";
import "../../services/bridge_settings_service.dart";
import "bridge_settings_state.dart";

class BridgeSettingsCubit({
  required final BridgeSettingsService _service,
  required ConnectionService connectionService,
}) extends Cubit<BridgeSettingsState> {
  this
    : super(
        connectionService.currentStatus is ConnectionConnected
            ? const BridgeSettingsLoading()
            : const BridgeSettingsDisconnected(),
      ) {
    _connectionStatusSubscription = connectionService.status.skip(1).listen(_onConnectionStatus);
    if (_connected) unawaited(refresh());
  }

  late final StreamSubscription<ConnectionStatus> _connectionStatusSubscription;
  bool _connected = connectionService.currentStatus is ConnectionConnected;
  int _connectionEpoch = 0;
  bool _operationInProgress = false;
  bool _refreshPending = false;

  Future<void> refresh() async {
    if (!_connected || isClosed) return;
    if (_operationInProgress) {
      _refreshPending = true;
      return;
    }
    _operationInProgress = true;
    _refreshPending = false;
    final operationEpoch = _connectionEpoch;
    emit(const BridgeSettingsLoading());
    try {
      final result = await _service.load();
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      _publishLoad(result: result);
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      emit(BridgeSettingsFailure(error: ApiError.dartHttpClient(error)));
    } finally {
      _finishOperation();
    }
  }

  Future<void> updateYolo({required bool enabled, required BridgeSettingsReady expectedState}) async {
    if (_operationInProgress || !_connected || isClosed) return;
    final current = state;
    if (current is! BridgeSettingsReady ||
        !identical(current, expectedState) ||
        current.yoloMutation is YoloMutationInProgress ||
        current.yoloMutation is YoloMutationUncertain ||
        current.yoloMutation is YoloMutationUnsupported ||
        current.yoloEnabled == enabled) {
      return;
    }
    _operationInProgress = true;
    final operationEpoch = _connectionEpoch;
    emit(_withYolo(state: current, enabled: current.yoloEnabled, mutation: const YoloMutationInProgress()));
    try {
      final result = await _service.updateYolo(enabled: enabled);
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      switch (result) {
        case YoloSettingsMutationCommitted(:final response):
          emit(_withYolo(state: current, enabled: response.enabled, mutation: const YoloMutationIdle()));
        case YoloSettingsMutationUnsupported():
          emit(_withYolo(state: current, enabled: current.yoloEnabled, mutation: const YoloMutationUnsupported()));
        case YoloSettingsMutationFailure(:final error):
          emit(
            _withYolo(
              state: current,
              enabled: current.yoloEnabled,
              mutation: YoloMutationFailed(error: error),
            ),
          );
        case YoloSettingsMutationUncertain():
          await _reconcileYolo(current: current, operationEpoch: operationEpoch);
      }
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      emit(
        _withYolo(
          state: current,
          enabled: current.yoloEnabled,
          mutation: YoloMutationFailed(error: ApiError.dartHttpClient(error)),
        ),
      );
    } finally {
      _finishOperation();
    }
  }

  Future<void> updatePluginWarmup({required bool enabled, required BridgeSettingsReady expectedState}) async {
    if (_operationInProgress || !_connected || isClosed) return;
    final current = state;
    if (current is! BridgeSettingsReady || !identical(current, expectedState)) return;
    final currentEnabled = switch (current.pluginWarmupMutation) {
      PluginWarmupMutationIdle(:final enabled) || PluginWarmupMutationFailed(:final enabled) => enabled,
      PluginWarmupMutationInProgress() || PluginWarmupMutationUncertain() || PluginWarmupMutationUnsupported() => null,
    };
    if (currentEnabled == null || currentEnabled == enabled) return;

    _operationInProgress = true;
    final operationEpoch = _connectionEpoch;
    emit(
      _withPluginWarmup(
        state: current,
        mutation: PluginWarmupMutationInProgress(enabled: currentEnabled),
      ),
    );
    try {
      final result = await _service.updatePluginWarmup(enabled: enabled);
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      switch (result) {
        case PluginWarmupSettingsMutationCommitted(:final enabled):
          emit(
            _withPluginWarmup(
              state: current,
              mutation: PluginWarmupMutationIdle(enabled: enabled),
            ),
          );
        case PluginWarmupSettingsMutationUnsupported():
          emit(_withPluginWarmup(state: current, mutation: const PluginWarmupMutationUnsupported()));
        case PluginWarmupSettingsMutationFailure(:final error):
          emit(
            _withPluginWarmup(
              state: current,
              mutation: PluginWarmupMutationFailed(enabled: currentEnabled, error: error),
            ),
          );
        case PluginWarmupSettingsMutationUncertain():
          await _reconcilePluginWarmup(
            current: current,
            currentEnabled: currentEnabled,
            operationEpoch: operationEpoch,
          );
      }
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      emit(
        _withPluginWarmup(
          state: current,
          mutation: PluginWarmupMutationFailed(
            enabled: currentEnabled,
            error: ApiError.dartHttpClient(error),
          ),
        ),
      );
    } finally {
      _finishOperation();
    }
  }

  Future<void> _reconcileYolo({required BridgeSettingsReady current, required int operationEpoch}) async {
    try {
      final result = await _service.load();
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      if (result case BridgeSettingsLoadFailure(:final error)) {
        emit(
          _withYolo(
            state: current,
            enabled: current.yoloEnabled,
            mutation: YoloMutationUncertain(refreshError: error),
          ),
        );
      } else {
        _publishLoad(result: result);
      }
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      emit(
        _withYolo(
          state: current,
          enabled: current.yoloEnabled,
          mutation: YoloMutationUncertain(refreshError: ApiError.dartHttpClient(error)),
        ),
      );
    }
  }

  Future<void> _reconcilePluginWarmup({
    required BridgeSettingsReady current,
    required bool currentEnabled,
    required int operationEpoch,
  }) async {
    try {
      final result = await _service.load();
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      if (result case BridgeSettingsLoadFailure(:final error)) {
        emit(
          _withPluginWarmup(
            state: current,
            mutation: PluginWarmupMutationUncertain(enabled: currentEnabled, refreshError: error),
          ),
        );
      } else {
        _publishLoad(result: result);
      }
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      emit(
        _withPluginWarmup(
          state: current,
          mutation: PluginWarmupMutationUncertain(
            enabled: currentEnabled,
            refreshError: ApiError.dartHttpClient(error),
          ),
        ),
      );
    }
  }

  void _publishLoad({required BridgeSettingsLoadResult result}) {
    switch (result) {
      case BridgeSettingsLoadSupported(:final response):
        emit(
          BridgeSettingsReady(
            yoloEnabled: response.yolo.enabled,
            yoloMutation: const YoloMutationIdle(),
            pluginWarmupMutation: switch (response.warmUpPluginsOnSessionOpen) {
              final bool enabled => PluginWarmupMutationIdle(enabled: enabled),
              null => const PluginWarmupMutationUnsupported(),
            },
          ),
        );
      case BridgeSettingsLoadUnsupported():
        emit(const BridgeSettingsUnsupported());
      case BridgeSettingsLoadFailure(:final error):
        emit(BridgeSettingsFailure(error: error));
    }
  }

  BridgeSettingsReady _withYolo({
    required BridgeSettingsReady state,
    required bool enabled,
    required YoloMutationState mutation,
  }) {
    return BridgeSettingsReady(
      yoloEnabled: enabled,
      yoloMutation: mutation,
      pluginWarmupMutation: state.pluginWarmupMutation,
    );
  }

  BridgeSettingsReady _withPluginWarmup({
    required BridgeSettingsReady state,
    required PluginWarmupMutationState mutation,
  }) {
    return BridgeSettingsReady(
      yoloEnabled: state.yoloEnabled,
      yoloMutation: state.yoloMutation,
      pluginWarmupMutation: mutation,
    );
  }

  void _onConnectionStatus(ConnectionStatus status) {
    if (isClosed) return;
    _connectionEpoch++;
    _connected = status is ConnectionConnected;
    _refreshPending = false;
    emit(_connected ? const BridgeSettingsLoading() : const BridgeSettingsDisconnected());
    if (_connected) unawaited(refresh());
  }

  bool _canPublish({required int operationEpoch}) => !isClosed && _connected && operationEpoch == _connectionEpoch;

  void _finishOperation() {
    _operationInProgress = false;
    if (!_refreshPending || !_connected || isClosed) return;
    _refreshPending = false;
    unawaited(refresh());
  }

  @override
  Future<void> close() async {
    _connected = false;
    _connectionEpoch++;
    await _connectionStatusSubscription.cancel();
    return await super.close();
  }
}
