import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../repositories/models/pull_request_refresh_settings_result.dart";
import "../../services/pull_request_refresh_settings_service.dart";
import "pull_request_refresh_settings_state.dart";

class PullRequestRefreshSettingsCubit extends Cubit<PullRequestRefreshSettingsState> {
  PullRequestRefreshSettingsCubit({
    required PullRequestRefreshSettingsService service,
    required ConnectionService connectionService,
  }) : _service = service,
       _connected = connectionService.currentStatus is ConnectionConnected,
       super(
         connectionService.currentStatus is ConnectionConnected
             ? const PullRequestRefreshSettingsLoading()
             : const PullRequestRefreshSettingsDisconnected(),
       ) {
    _connectionStatusSubscription = connectionService.status.skip(1).listen(_onConnectionStatus);
    if (_connected) unawaited(refresh());
  }

  final PullRequestRefreshSettingsService _service;
  late final StreamSubscription<ConnectionStatus> _connectionStatusSubscription;
  bool _connected;
  int _connectionEpoch = 0;
  bool _operationInProgress = false;
  bool _refreshPending = false;

  PullRequestRefreshSettingsInputValidation validateUpdateInput({required String input}) {
    return switch (_planUpdate(input: input)) {
      PullRequestRefreshSettingsUpdateInvalid() => PullRequestRefreshSettingsInputValidation.invalid,
      PullRequestRefreshSettingsUpdateRequest() => PullRequestRefreshSettingsInputValidation.valid,
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
    emit(const PullRequestRefreshSettingsLoading());
    try {
      final result = await _service.load();
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      _publishLoad(result: result, validationBounds: validationBounds);
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      emit(
        PullRequestRefreshSettingsFailure(
          error: ApiError.dartHttpClient(error),
          validationBounds: validationBounds,
        ),
      );
    } finally {
      _finishOperation();
    }
  }

  Future<PullRequestRefreshSettingsUpdateAcceptance> update({
    required String input,
    required PullRequestRefreshSettingsReady expectedState,
  }) async {
    if (_operationInProgress || !_connected || isClosed) {
      return PullRequestRefreshSettingsUpdateAcceptance.rejected;
    }
    final current = state;
    if (current is! PullRequestRefreshSettingsReady ||
        !identical(current, expectedState) ||
        current.mutation is PullRequestRefreshSettingsMutationInProgress) {
      return PullRequestRefreshSettingsUpdateAcceptance.rejected;
    }

    switch (_planUpdate(input: input)) {
      case PullRequestRefreshSettingsUpdateInvalid():
        emit(
          PullRequestRefreshSettingsReady(
            intervalSeconds: current.intervalSeconds,
            mutation: PullRequestRefreshSettingsMutationFailed(
              error: const PullRequestRefreshSettingsInvalidInput(),
              validationBounds: current.validationBounds,
            ),
          ),
        );
      case PullRequestRefreshSettingsUpdateRequest(:final intervalSeconds):
        _operationInProgress = true;
        final operationEpoch = _connectionEpoch;
        emit(
          PullRequestRefreshSettingsReady(
            intervalSeconds: current.intervalSeconds,
            mutation: PullRequestRefreshSettingsMutationInProgress(
              validationBounds: current.validationBounds,
            ),
          ),
        );
        try {
          final result = await _service.update(intervalSeconds: intervalSeconds);
          if (!_canPublish(operationEpoch: operationEpoch)) {
            return PullRequestRefreshSettingsUpdateAcceptance.accepted;
          }
          switch (result) {
            case PullRequestRefreshSettingsMutationCommitted(:final response):
              emit(
                PullRequestRefreshSettingsReady(
                  intervalSeconds: response.intervalSeconds,
                  mutation: PullRequestRefreshSettingsMutationIdle(
                    validationBounds: current.validationBounds,
                  ),
                ),
              );
            case PullRequestRefreshSettingsMutationUnsupported():
              emit(const PullRequestRefreshSettingsUnsupported());
            case PullRequestRefreshSettingsMutationRejected(:final bounds):
              emit(
                PullRequestRefreshSettingsReady(
                  intervalSeconds: current.intervalSeconds,
                  mutation: PullRequestRefreshSettingsMutationRangeRejected(bounds: bounds),
                ),
              );
            case PullRequestRefreshSettingsMutationFailure(:final error):
              emit(
                PullRequestRefreshSettingsReady(
                  intervalSeconds: current.intervalSeconds,
                  mutation: PullRequestRefreshSettingsMutationFailed(
                    error: PullRequestRefreshSettingsRequestFailed(error: error),
                    validationBounds: current.validationBounds,
                  ),
                ),
              );
            case PullRequestRefreshSettingsMutationUncertain():
              await _reconcileUncertainMutation(
                validationBounds: current.validationBounds,
                operationEpoch: operationEpoch,
              );
          }
        } on Object catch (error) {
          if (!_canPublish(operationEpoch: operationEpoch)) {
            return PullRequestRefreshSettingsUpdateAcceptance.accepted;
          }
          emit(
            PullRequestRefreshSettingsReady(
              intervalSeconds: current.intervalSeconds,
              mutation: PullRequestRefreshSettingsMutationFailed(
                error: PullRequestRefreshSettingsRequestFailed(
                  error: ApiError.dartHttpClient(error),
                ),
                validationBounds: current.validationBounds,
              ),
            ),
          );
        } finally {
          _finishOperation();
        }
    }
    return PullRequestRefreshSettingsUpdateAcceptance.accepted;
  }

  Future<void> _reconcileUncertainMutation({
    required PullRequestRefreshSettingsBounds? validationBounds,
    required int operationEpoch,
  }) async {
    try {
      final result = await _service.load();
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      switch (result) {
        case PullRequestRefreshSettingsLoadSupported(:final response):
          emit(
            PullRequestRefreshSettingsReady(
              intervalSeconds: response.intervalSeconds,
              mutation: PullRequestRefreshSettingsMutationIdle(
                validationBounds: validationBounds,
              ),
            ),
          );
        case PullRequestRefreshSettingsLoadUnsupported():
          emit(const PullRequestRefreshSettingsUnsupported());
        case PullRequestRefreshSettingsLoadFailure(:final error):
          emit(
            PullRequestRefreshSettingsUncertain(
              refreshError: error,
              validationBounds: validationBounds,
            ),
          );
      }
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      emit(
        PullRequestRefreshSettingsUncertain(
          refreshError: ApiError.dartHttpClient(error),
          validationBounds: validationBounds,
        ),
      );
    }
  }

  PullRequestRefreshSettingsUpdatePlan _planUpdate({required String input}) {
    return _service.planUpdate(
      input: input,
      bounds: _validationBoundsFor(state: state),
    );
  }

  PullRequestRefreshSettingsBounds? _validationBoundsFor({required PullRequestRefreshSettingsState state}) {
    return switch (state) {
      PullRequestRefreshSettingsReady(:final validationBounds) => validationBounds,
      PullRequestRefreshSettingsFailure(:final validationBounds) => validationBounds,
      PullRequestRefreshSettingsUncertain(:final validationBounds) => validationBounds,
      PullRequestRefreshSettingsLoading() ||
      PullRequestRefreshSettingsDisconnected() ||
      PullRequestRefreshSettingsUnsupported() => null,
    };
  }

  void _onConnectionStatus(ConnectionStatus status) {
    if (isClosed) return;
    _connectionEpoch++;
    _connected = status is ConnectionConnected;
    _refreshPending = false;
    emit(
      _connected ? const PullRequestRefreshSettingsLoading() : const PullRequestRefreshSettingsDisconnected(),
    );
    if (_connected) unawaited(refresh());
  }

  bool _canPublish({required int operationEpoch}) {
    return !isClosed && _connected && operationEpoch == _connectionEpoch;
  }

  void _finishOperation() {
    _operationInProgress = false;
    if (!_refreshPending || !_connected || isClosed) return;
    _refreshPending = false;
    unawaited(refresh());
  }

  void _publishLoad({
    required PullRequestRefreshSettingsLoadResult result,
    required PullRequestRefreshSettingsBounds? validationBounds,
  }) {
    switch (result) {
      case PullRequestRefreshSettingsLoadSupported(:final response):
        emit(
          PullRequestRefreshSettingsReady(
            intervalSeconds: response.intervalSeconds,
            mutation: PullRequestRefreshSettingsMutationIdle(
              validationBounds: validationBounds,
            ),
          ),
        );
      case PullRequestRefreshSettingsLoadUnsupported():
        emit(const PullRequestRefreshSettingsUnsupported());
      case PullRequestRefreshSettingsLoadFailure(:final error):
        emit(
          PullRequestRefreshSettingsFailure(
            error: error,
            validationBounds: validationBounds,
          ),
        );
    }
  }

  @override
  Future<void> close() async {
    _connected = false;
    _connectionEpoch++;
    await _connectionStatusSubscription.cancel();
    return super.close();
  }
}

enum PullRequestRefreshSettingsInputValidation { valid, invalid }

enum PullRequestRefreshSettingsUpdateAcceptance { accepted, rejected }
