import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../repositories/bridge_settings_repository.dart";
import "../../repositories/models/bridge_settings_result.dart";
import "bridge_settings_state.dart";

class BridgeSettingsCubit({
  required final BridgeSettingsRepository _repository,
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

  PullRequestRefreshInputValidation validatePullRequestRefreshInput({required String input}) {
    return switch (_planPullRequestRefreshUpdate(input: input)) {
      PullRequestRefreshSettingsUpdateInvalid() => PullRequestRefreshInputValidation.invalid,
      PullRequestRefreshSettingsUpdateRequest() => PullRequestRefreshInputValidation.valid,
    };
  }

  Future<void> refresh() async {
    if (!_connected || isClosed) return;
    if (_operationInProgress) {
      _refreshPending = true;
      return;
    }
    _operationInProgress = true;
    _refreshPending = false;
    final operationEpoch = _connectionEpoch;
    final validationBounds = _validationBoundsFor(state: state);
    emit(const BridgeSettingsLoading());
    try {
      final result = await _repository.load();
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      _publishLoad(result: result, validationBounds: validationBounds);
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      emit(BridgeSettingsFailure(error: ApiError.dartHttpClient(error), validationBounds: validationBounds));
    } finally {
      _finishOperation();
    }
  }

  Future<BridgeSettingsUpdateAcceptance> updatePullRequestRefresh({
    required String input,
    required BridgeSettingsReady expectedState,
  }) async {
    if (_operationInProgress || !_connected || isClosed) return BridgeSettingsUpdateAcceptance.rejected;
    final current = state;
    if (current is! BridgeSettingsReady ||
        !identical(current, expectedState) ||
        current.pullRequestRefreshMutation is PullRequestRefreshMutationInProgress ||
        current.pullRequestRefreshMutation is PullRequestRefreshMutationUncertain ||
        current.pullRequestRefreshMutation is PullRequestRefreshMutationUnsupported) {
      return BridgeSettingsUpdateAcceptance.rejected;
    }

    switch (_planPullRequestRefreshUpdate(input: input)) {
      case PullRequestRefreshSettingsUpdateInvalid():
        emit(
          _withPullRequestRefresh(
            state: current,
            intervalSeconds: current.pullRequestRefreshIntervalSeconds,
            mutation: PullRequestRefreshMutationFailed(
              error: const PullRequestRefreshInvalidInput(),
              validationBounds: current.validationBounds,
            ),
          ),
        );
      case PullRequestRefreshSettingsUpdateRequest(:final intervalSeconds):
        _operationInProgress = true;
        final operationEpoch = _connectionEpoch;
        emit(
          _withPullRequestRefresh(
            state: current,
            intervalSeconds: current.pullRequestRefreshIntervalSeconds,
            mutation: PullRequestRefreshMutationInProgress(validationBounds: current.validationBounds),
          ),
        );
        try {
          final result = await _repository.updatePullRequestRefresh(intervalSeconds: intervalSeconds);
          if (!_canPublish(operationEpoch: operationEpoch)) return BridgeSettingsUpdateAcceptance.accepted;
          switch (result) {
            case PullRequestRefreshSettingsMutationCommitted(:final response):
              emit(
                _withPullRequestRefresh(
                  state: current,
                  intervalSeconds: response.intervalSeconds,
                  mutation: PullRequestRefreshMutationIdle(validationBounds: current.validationBounds),
                ),
              );
            case PullRequestRefreshSettingsMutationUnsupported():
              emit(
                _withPullRequestRefresh(
                  state: current,
                  intervalSeconds: current.pullRequestRefreshIntervalSeconds,
                  mutation: PullRequestRefreshMutationUnsupported(validationBounds: current.validationBounds),
                ),
              );
            case PullRequestRefreshSettingsMutationRejected(:final bounds):
              emit(
                _withPullRequestRefresh(
                  state: current,
                  intervalSeconds: current.pullRequestRefreshIntervalSeconds,
                  mutation: PullRequestRefreshMutationRangeRejected(bounds: bounds),
                ),
              );
            case PullRequestRefreshSettingsMutationFailure(:final error):
              emit(
                _withPullRequestRefresh(
                  state: current,
                  intervalSeconds: current.pullRequestRefreshIntervalSeconds,
                  mutation: PullRequestRefreshMutationFailed(
                    error: PullRequestRefreshRequestFailed(error: error),
                    validationBounds: current.validationBounds,
                  ),
                ),
              );
            case PullRequestRefreshSettingsMutationUncertain():
              await _reconcilePullRequestRefresh(current: current, operationEpoch: operationEpoch);
          }
        } on Object catch (error) {
          if (!_canPublish(operationEpoch: operationEpoch)) return BridgeSettingsUpdateAcceptance.accepted;
          emit(
            _withPullRequestRefresh(
              state: current,
              intervalSeconds: current.pullRequestRefreshIntervalSeconds,
              mutation: PullRequestRefreshMutationFailed(
                error: PullRequestRefreshRequestFailed(error: ApiError.dartHttpClient(error)),
                validationBounds: current.validationBounds,
              ),
            ),
          );
        } finally {
          _finishOperation();
        }
    }
    return BridgeSettingsUpdateAcceptance.accepted;
  }

  Future<void> updateYolo({required bool enabled, required BridgeSettingsReadyFull expectedState}) async {
    if (_operationInProgress || !_connected || isClosed) return;
    final current = state;
    if (current is! BridgeSettingsReadyFull ||
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
      final result = await _repository.updateYolo(enabled: enabled);
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

  Future<void> updatePluginWarmup({required bool enabled, required BridgeSettingsReadyFull expectedState}) async {
    if (_operationInProgress || !_connected || isClosed) return;
    final current = state;
    if (current is! BridgeSettingsReadyFull || !identical(current, expectedState)) return;
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
      final result = await _repository.updatePluginWarmup(enabled: enabled);
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

  Future<void> _reconcilePullRequestRefresh({
    required BridgeSettingsReady current,
    required int operationEpoch,
  }) async {
    try {
      final result = await _repository.load();
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      if (result case BridgeSettingsLoadFailure(:final error)) {
        emit(
          _withPullRequestRefresh(
            state: current,
            intervalSeconds: current.pullRequestRefreshIntervalSeconds,
            mutation: PullRequestRefreshMutationUncertain(
              refreshError: error,
              validationBounds: current.validationBounds,
            ),
          ),
        );
      } else {
        _publishLoad(result: result, validationBounds: current.validationBounds);
      }
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      emit(
        _withPullRequestRefresh(
          state: current,
          intervalSeconds: current.pullRequestRefreshIntervalSeconds,
          mutation: PullRequestRefreshMutationUncertain(
            refreshError: ApiError.dartHttpClient(error),
            validationBounds: current.validationBounds,
          ),
        ),
      );
    }
  }

  Future<void> _reconcileYolo({required BridgeSettingsReadyFull current, required int operationEpoch}) async {
    try {
      final result = await _repository.load();
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
        _publishLoad(result: result, validationBounds: current.validationBounds);
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
    required BridgeSettingsReadyFull current,
    required bool currentEnabled,
    required int operationEpoch,
  }) async {
    try {
      final result = await _repository.load();
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      if (result case BridgeSettingsLoadFailure(:final error)) {
        emit(
          _withPluginWarmup(
            state: current,
            mutation: PluginWarmupMutationUncertain(enabled: currentEnabled, refreshError: error),
          ),
        );
      } else {
        _publishLoad(result: result, validationBounds: current.validationBounds);
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

  PullRequestRefreshSettingsUpdatePlan _planPullRequestRefreshUpdate({required String input}) {
    return PullRequestRefreshSettingsUpdatePlan.parse(
      input: input,
      bounds: _validationBoundsFor(state: state),
    );
  }

  PullRequestRefreshSettingsBounds? _validationBoundsFor({required BridgeSettingsState state}) {
    return switch (state) {
      BridgeSettingsReady(:final validationBounds) => validationBounds,
      BridgeSettingsFailure(:final validationBounds) => validationBounds,
      BridgeSettingsLoading() || BridgeSettingsDisconnected() || BridgeSettingsUnsupported() => null,
    };
  }

  void _publishLoad({
    required BridgeSettingsLoadResult result,
    required PullRequestRefreshSettingsBounds? validationBounds,
  }) {
    switch (result) {
      case BridgeSettingsLoadSupported(:final response):
        emit(
          BridgeSettingsReadyFull(
            pullRequestRefreshIntervalSeconds: response.pullRequestRefresh.intervalSeconds,
            pullRequestRefreshMutation: PullRequestRefreshMutationIdle(validationBounds: validationBounds),
            yoloEnabled: response.yolo.enabled,
            yoloMutation: const YoloMutationIdle(),
            pluginWarmupMutation: switch (response.warmUpPluginsOnSessionOpen) {
              final bool enabled => PluginWarmupMutationIdle(enabled: enabled),
              null => const PluginWarmupMutationUnsupported(),
            },
          ),
        );
      case BridgeSettingsLoadLegacyPartial(:final pullRequestRefresh):
        emit(
          BridgeSettingsReadyLegacyPartial(
            pullRequestRefreshIntervalSeconds: pullRequestRefresh.intervalSeconds,
            pullRequestRefreshMutation: PullRequestRefreshMutationIdle(validationBounds: validationBounds),
          ),
        );
      case BridgeSettingsLoadUnsupported():
        emit(const BridgeSettingsUnsupported());
      case BridgeSettingsLoadFailure(:final error):
        emit(BridgeSettingsFailure(error: error, validationBounds: validationBounds));
    }
  }

  BridgeSettingsReady _withPullRequestRefresh({
    required BridgeSettingsReady state,
    required int intervalSeconds,
    required PullRequestRefreshMutationState mutation,
  }) {
    return switch (state) {
      BridgeSettingsReadyFull(
        :final yoloEnabled,
        :final yoloMutation,
        :final pluginWarmupMutation,
      ) =>
        BridgeSettingsReadyFull(
          pullRequestRefreshIntervalSeconds: intervalSeconds,
          pullRequestRefreshMutation: mutation,
          yoloEnabled: yoloEnabled,
          yoloMutation: yoloMutation,
          pluginWarmupMutation: pluginWarmupMutation,
        ),
      BridgeSettingsReadyLegacyPartial() => BridgeSettingsReadyLegacyPartial(
        pullRequestRefreshIntervalSeconds: intervalSeconds,
        pullRequestRefreshMutation: mutation,
      ),
    };
  }

  BridgeSettingsReadyFull _withYolo({
    required BridgeSettingsReadyFull state,
    required bool enabled,
    required YoloMutationState mutation,
  }) {
    return BridgeSettingsReadyFull(
      pullRequestRefreshIntervalSeconds: state.pullRequestRefreshIntervalSeconds,
      pullRequestRefreshMutation: state.pullRequestRefreshMutation,
      yoloEnabled: enabled,
      yoloMutation: mutation,
      pluginWarmupMutation: state.pluginWarmupMutation,
    );
  }

  BridgeSettingsReadyFull _withPluginWarmup({
    required BridgeSettingsReadyFull state,
    required PluginWarmupMutationState mutation,
  }) {
    return BridgeSettingsReadyFull(
      pullRequestRefreshIntervalSeconds: state.pullRequestRefreshIntervalSeconds,
      pullRequestRefreshMutation: state.pullRequestRefreshMutation,
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

enum PullRequestRefreshInputValidation() {
  valid,
  invalid,
}

enum BridgeSettingsUpdateAcceptance() {
  accepted,
  rejected,
}
