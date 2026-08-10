import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../repositories/models/yolo_settings_result.dart";
import "../../repositories/yolo_settings_repository.dart";
import "yolo_settings_state.dart";

class YoloSettingsCubit extends Cubit<YoloSettingsState> {
  YoloSettingsCubit({required YoloSettingsRepository repository, required ConnectionService connectionService})
    : _repository = repository,
      _connected = connectionService.currentStatus is ConnectionConnected,
      super(
        connectionService.currentStatus is ConnectionConnected
            ? const YoloSettingsLoading()
            : const YoloSettingsDisconnected(),
      ) {
    _connectionStatusSubscription = connectionService.status.skip(1).listen(_onConnectionStatus);
    if (_connected) unawaited(refresh());
  }

  final YoloSettingsRepository _repository;
  late final StreamSubscription<ConnectionStatus> _connectionStatusSubscription;
  bool _connected;
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
    emit(const YoloSettingsLoading());
    try {
      final result = await _repository.load();
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      _publishLoad(result: result);
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      emit(YoloSettingsFailure(error: ApiError.dartHttpClient(error)));
    } finally {
      _finishOperation();
    }
  }

  Future<void> update({required bool enabled, required YoloSettingsReady expectedState}) async {
    if (_operationInProgress || !_connected || isClosed) return;
    final current = state;
    if (current is! YoloSettingsReady ||
        !identical(current, expectedState) ||
        current.mutation is YoloSettingsMutationInProgress ||
        current.enabled == enabled) {
      return;
    }

    _operationInProgress = true;
    final operationEpoch = _connectionEpoch;
    emit(YoloSettingsReady(enabled: current.enabled, mutation: const YoloSettingsMutationInProgress()));
    try {
      final result = await _repository.update(enabled: enabled);
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      switch (result) {
        case YoloSettingsMutationCommitted(:final response):
          emit(YoloSettingsReady(enabled: response.enabled, mutation: const YoloSettingsMutationIdle()));
        case YoloSettingsMutationUnsupported():
          emit(const YoloSettingsUnsupported());
        case YoloSettingsMutationFailure(:final error):
          emit(
            YoloSettingsReady(
              enabled: current.enabled,
              mutation: YoloSettingsMutationFailed(error: error),
            ),
          );
        case YoloSettingsMutationUncertain():
          await _reconcileUncertainMutation(operationEpoch: operationEpoch);
      }
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      emit(
        YoloSettingsReady(
          enabled: current.enabled,
          mutation: YoloSettingsMutationFailed(error: ApiError.dartHttpClient(error)),
        ),
      );
    } finally {
      _finishOperation();
    }
  }

  Future<void> _reconcileUncertainMutation({required int operationEpoch}) async {
    try {
      final result = await _repository.load();
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      switch (result) {
        case YoloSettingsLoadSupported(:final response):
          emit(YoloSettingsReady(enabled: response.enabled, mutation: const YoloSettingsMutationIdle()));
        case YoloSettingsLoadUnsupported():
          emit(const YoloSettingsUnsupported());
        case YoloSettingsLoadFailure(:final error):
          emit(YoloSettingsUncertain(refreshError: error));
      }
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      emit(YoloSettingsUncertain(refreshError: ApiError.dartHttpClient(error)));
    }
  }

  void _publishLoad({required YoloSettingsLoadResult result}) {
    switch (result) {
      case YoloSettingsLoadSupported(:final response):
        emit(YoloSettingsReady(enabled: response.enabled, mutation: const YoloSettingsMutationIdle()));
      case YoloSettingsLoadUnsupported():
        emit(const YoloSettingsUnsupported());
      case YoloSettingsLoadFailure(:final error):
        emit(YoloSettingsFailure(error: error));
    }
  }

  void _onConnectionStatus(ConnectionStatus status) {
    if (isClosed) return;
    _connectionEpoch++;
    _connected = status is ConnectionConnected;
    _refreshPending = false;
    emit(_connected ? const YoloSettingsLoading() : const YoloSettingsDisconnected());
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
    return super.close();
  }
}
