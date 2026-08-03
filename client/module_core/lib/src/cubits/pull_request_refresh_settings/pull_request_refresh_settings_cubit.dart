import "dart:async";

import "package:bloc/bloc.dart";

import "../../repositories/models/pull_request_refresh_settings_result.dart";
import "../../services/pull_request_refresh_settings_service.dart";
import "pull_request_refresh_settings_state.dart";

class PullRequestRefreshSettingsCubit extends Cubit<PullRequestRefreshSettingsState> {
  PullRequestRefreshSettingsCubit({required PullRequestRefreshSettingsService service})
    : _service = service,
      super(const PullRequestRefreshSettingsLoading()) {
    unawaited(refresh());
  }

  final PullRequestRefreshSettingsService _service;
  bool _operationInProgress = false;

  PullRequestRefreshSettingsInputValidation validateUpdateInput({required String input}) {
    return switch (_service.planUpdate(input: input)) {
      PullRequestRefreshSettingsUpdateInvalid() => PullRequestRefreshSettingsInputValidation.invalid,
      PullRequestRefreshSettingsUpdateRequest() => PullRequestRefreshSettingsInputValidation.valid,
    };
  }

  Future<void> refresh() async {
    if (_operationInProgress || isClosed) return;
    _operationInProgress = true;
    emit(const PullRequestRefreshSettingsLoading());
    final result = await _service.load();
    if (isClosed) return;
    _operationInProgress = false;
    _publishLoad(result: result);
  }

  Future<void> update({required String input}) async {
    if (_operationInProgress || isClosed) return;
    final current = state;
    if (current is! PullRequestRefreshSettingsReady ||
        current.mutation is PullRequestRefreshSettingsMutationInProgress) {
      return;
    }

    switch (_service.planUpdate(input: input)) {
      case PullRequestRefreshSettingsUpdateInvalid():
        emit(
          PullRequestRefreshSettingsReady(
            intervalSeconds: current.intervalSeconds,
            mutation: const PullRequestRefreshSettingsMutationFailed(
              error: PullRequestRefreshSettingsInvalidInput(),
            ),
          ),
        );
      case PullRequestRefreshSettingsUpdateRequest(:final request):
        _operationInProgress = true;
        emit(
          PullRequestRefreshSettingsReady(
            intervalSeconds: current.intervalSeconds,
            mutation: const PullRequestRefreshSettingsMutationInProgress(),
          ),
        );
        final result = await _service.update(request: request);
        if (isClosed) return;
        switch (result) {
          case PullRequestRefreshSettingsMutationCommitted(:final response):
            _operationInProgress = false;
            emit(
              PullRequestRefreshSettingsReady(
                intervalSeconds: response.intervalSeconds,
                mutation: const PullRequestRefreshSettingsMutationIdle(),
              ),
            );
          case PullRequestRefreshSettingsMutationUnsupported():
            _operationInProgress = false;
            emit(const PullRequestRefreshSettingsUnsupported());
          case PullRequestRefreshSettingsMutationRejected(:final error):
            _operationInProgress = false;
            emit(
              PullRequestRefreshSettingsReady(
                intervalSeconds: current.intervalSeconds,
                mutation: PullRequestRefreshSettingsMutationFailed(
                  error: PullRequestRefreshSettingsRejected(
                    minimumIntervalSeconds: error.minimumIntervalSeconds,
                    maximumIntervalSeconds: error.maximumIntervalSeconds,
                  ),
                ),
              ),
            );
          case PullRequestRefreshSettingsMutationFailure(:final error):
            _operationInProgress = false;
            emit(
              PullRequestRefreshSettingsReady(
                intervalSeconds: current.intervalSeconds,
                mutation: PullRequestRefreshSettingsMutationFailed(
                  error: PullRequestRefreshSettingsRequestFailed(error: error),
                ),
              ),
            );
          case PullRequestRefreshSettingsMutationUncertain():
            await _reconcileUncertainMutation(lastKnownIntervalSeconds: current.intervalSeconds);
        }
    }
  }

  Future<void> _reconcileUncertainMutation({required int lastKnownIntervalSeconds}) async {
    final result = await _service.load();
    if (isClosed) return;
    _operationInProgress = false;
    switch (result) {
      case PullRequestRefreshSettingsLoadSupported(:final response):
        emit(
          PullRequestRefreshSettingsReady(
            intervalSeconds: response.intervalSeconds,
            mutation: const PullRequestRefreshSettingsMutationIdle(),
          ),
        );
      case PullRequestRefreshSettingsLoadUnsupported():
        emit(const PullRequestRefreshSettingsUnsupported());
      case PullRequestRefreshSettingsLoadFailure(:final error):
        emit(
          PullRequestRefreshSettingsUncertain(
            lastKnownIntervalSeconds: lastKnownIntervalSeconds,
            refreshError: error,
          ),
        );
    }
  }

  void _publishLoad({required PullRequestRefreshSettingsLoadResult result}) {
    switch (result) {
      case PullRequestRefreshSettingsLoadSupported(:final response):
        emit(
          PullRequestRefreshSettingsReady(
            intervalSeconds: response.intervalSeconds,
            mutation: const PullRequestRefreshSettingsMutationIdle(),
          ),
        );
      case PullRequestRefreshSettingsLoadUnsupported():
        emit(const PullRequestRefreshSettingsUnsupported());
      case PullRequestRefreshSettingsLoadFailure(:final error):
        emit(PullRequestRefreshSettingsFailure(error: error));
    }
  }
}

enum PullRequestRefreshSettingsInputValidation { valid, invalid }
