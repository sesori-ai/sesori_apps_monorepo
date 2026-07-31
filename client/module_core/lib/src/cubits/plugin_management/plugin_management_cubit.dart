import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../repositories/models/plugin_management_result.dart";
import "../../services/plugin_management_service.dart";
import "plugin_management_state.dart";

class PluginManagementCubit extends Cubit<PluginManagementState> {
  PluginManagementCubit({required PluginManagementService service})
    : _service = service,
      super(const PluginManagementState.loading()) {
    _snapshotSubscription = service.snapshots.listen((snapshot) => _onSnapshot(snapshot: snapshot));
  }

  final PluginManagementService _service;
  late final StreamSubscription<PluginManagementLoadResult> _snapshotSubscription;
  int _actionGeneration = 0;

  Future<void> refresh() => _service.refresh();

  Future<void> enable({required String pluginId}) => _runCommand(
    pluginId: pluginId,
    request: const PluginLifecycleCommandRequest.enable(),
    forceAction: null,
    replacePendingConfirmation: false,
  );

  Future<void> disable({required String pluginId}) => _runCommand(
    pluginId: pluginId,
    request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
    forceAction: PluginManagementForceAction.disable,
    replacePendingConfirmation: false,
  );

  Future<void> restart({required String pluginId}) => _runCommand(
    pluginId: pluginId,
    request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
    forceAction: PluginManagementForceAction.restart,
    replacePendingConfirmation: false,
  );

  Future<void> refreshSetup({required String pluginId}) => _runCommand(
    pluginId: pluginId,
    request: const PluginLifecycleCommandRequest.refresh(),
    forceAction: null,
    replacePendingConfirmation: false,
  );

  Future<void> applyIdleTimeoutToAll({required PluginManagementIdleTimeoutInput input}) => _runTimeoutPlan(
    target: const PluginManagementActionTarget.allHarnesses(),
    plan: _service.planApplyAllIdleTimeout(input: input),
  );

  Future<void> setIdleTimeoutOverride({
    required String pluginId,
    required PluginManagementIdleTimeoutInput input,
  }) => _runTimeoutPlan(
    target: PluginManagementActionTarget.harness(pluginId: pluginId),
    plan: _service.planSetIdleTimeoutOverride(pluginId: pluginId, input: input),
  );

  Future<void> clearIdleTimeoutOverride({required String pluginId}) => _runTimeoutPlan(
    target: PluginManagementActionTarget.harness(pluginId: pluginId),
    plan: _service.planClearIdleTimeoutOverride(pluginId: pluginId),
  );

  Future<void> confirmForce() async {
    final current = state;
    final pending = switch (current) {
      PluginManagementReady(action: final PluginManagementActionForceConfirmationRequired pending) => pending,
      PluginManagementReady() ||
      PluginManagementLoading() ||
      PluginManagementUnsupported() ||
      PluginManagementFailure() => null,
    };
    if (pending == null) return;
    await _runCommand(
      pluginId: pending.pluginId,
      request: pending.request,
      forceAction: null,
      replacePendingConfirmation: true,
    );
  }

  void dismissForceConfirmation() {
    if (isClosed) return;
    final current = state;
    if (current is! PluginManagementReady || current.action is! PluginManagementActionForceConfirmationRequired) {
      return;
    }
    _actionGeneration++;
    emit(current.copyWith(action: const PluginManagementActionState.idle()));
  }

  void dismissActionError() {
    if (isClosed) return;
    final current = state;
    if (current is! PluginManagementReady || current.action is! PluginManagementActionFailed) return;
    _actionGeneration++;
    emit(current.copyWith(action: const PluginManagementActionState.idle()));
  }

  void dismissRefreshError() {
    if (isClosed) return;
    final current = state;
    if (current is! PluginManagementReady || current.refresh is! PluginManagementRefreshFailed) return;
    emit(current.copyWith(refresh: const PluginManagementRefreshState.idle()));
  }

  Future<void> _runCommand({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
    required PluginManagementForceAction? forceAction,
    required bool replacePendingConfirmation,
  }) async {
    final target = PluginManagementActionTarget.harness(pluginId: pluginId);
    final generation = _beginAction(target: target, replacePendingConfirmation: replacePendingConfirmation);
    if (generation == null) return;

    final result = await _service.command(pluginId: pluginId, request: request);
    if (!_canFinishAction(generation: generation)) return;

    switch (result) {
      case PluginManagementMutationResultSuccess():
        _finishAction(generation: generation, action: const PluginManagementActionState.idle());
      case PluginManagementMutationResultNotFound():
        _finishAction(
          generation: generation,
          action: PluginManagementActionState.failed(
            target: target,
            error: const PluginManagementActionError.notFound(),
          ),
        );
      case PluginManagementMutationResultConflict(:final conflict):
        final actionState = switch (forceAction) {
          final forceAction? => switch (_service.assessForce(conflict: conflict, action: forceAction)) {
            PluginManagementForceAssessmentRequiresConfirmation(:final request) =>
              PluginManagementActionState.forceConfirmationRequired(
                pluginId: pluginId,
                action: forceAction,
                conflict: conflict,
                request: request,
              ),
            PluginManagementForceAssessmentNotForceable() => PluginManagementActionState.failed(
              target: target,
              error: PluginManagementActionError.conflict(conflict: conflict),
            ),
          },
          null => PluginManagementActionState.failed(
            target: target,
            error: PluginManagementActionError.conflict(conflict: conflict),
          ),
        };
        _finishAction(generation: generation, action: actionState);
      case PluginManagementMutationResultUncertain():
        _finishAction(
          generation: generation,
          action: PluginManagementActionState.failed(
            target: target,
            error: const PluginManagementActionError.uncertain(),
          ),
        );
      case PluginManagementMutationResultFailure(:final error):
        _finishAction(
          generation: generation,
          action: PluginManagementActionState.failed(
            target: target,
            error: PluginManagementActionError.request(error: error),
          ),
        );
    }
  }

  Future<void> _runTimeoutPlan({
    required PluginManagementActionTarget target,
    required PluginManagementCommandPlan plan,
  }) async {
    switch (plan) {
      case PluginManagementCommandPlanInvalidInput():
        _emitImmediateFailure(
          target: target,
          error: const PluginManagementActionError.invalidIdleTimeout(),
        );
      case PluginManagementCommandPlanRequest(:final request):
        final generation = _beginAction(target: target, replacePendingConfirmation: false);
        if (generation == null) return;
        final result = await _service.updateIdleTimeout(request: request);
        if (!_canFinishAction(generation: generation)) return;
        final action = switch (result) {
          PluginManagementMutationResultSuccess() => const PluginManagementActionState.idle(),
          PluginManagementMutationResultNotFound() => PluginManagementActionState.failed(
            target: target,
            error: const PluginManagementActionError.notFound(),
          ),
          PluginManagementMutationResultConflict(:final conflict) => PluginManagementActionState.failed(
            target: target,
            error: PluginManagementActionError.conflict(conflict: conflict),
          ),
          PluginManagementMutationResultUncertain() => PluginManagementActionState.failed(
            target: target,
            error: const PluginManagementActionError.uncertain(),
          ),
          PluginManagementMutationResultFailure(:final error) => PluginManagementActionState.failed(
            target: target,
            error: PluginManagementActionError.request(error: error),
          ),
        };
        _finishAction(generation: generation, action: action);
    }
  }

  int? _beginAction({
    required PluginManagementActionTarget target,
    required bool replacePendingConfirmation,
  }) {
    if (isClosed) return null;
    final current = state;
    if (current is! PluginManagementReady) return null;
    final canBegin =
        current.action is PluginManagementActionIdle ||
        current.action is PluginManagementActionFailed ||
        (replacePendingConfirmation && current.action is PluginManagementActionForceConfirmationRequired);
    if (!canBegin) return null;
    final generation = ++_actionGeneration;
    emit(current.copyWith(action: PluginManagementActionState.inProgress(target: target)));
    return generation;
  }

  bool _canFinishAction({required int generation}) {
    return !isClosed && generation == _actionGeneration && state is PluginManagementReady;
  }

  void _finishAction({required int generation, required PluginManagementActionState action}) {
    if (isClosed || generation != _actionGeneration) return;
    final current = state;
    if (current is! PluginManagementReady) return;
    emit(current.copyWith(action: action));
  }

  void _emitImmediateFailure({
    required PluginManagementActionTarget target,
    required PluginManagementActionError error,
  }) {
    if (isClosed) return;
    final current = state;
    if (current is! PluginManagementReady ||
        (current.action is! PluginManagementActionIdle && current.action is! PluginManagementActionFailed)) {
      return;
    }
    _actionGeneration++;
    emit(
      current.copyWith(
        action: PluginManagementActionState.failed(target: target, error: error),
      ),
    );
  }

  void _onSnapshot({required PluginManagementLoadResult snapshot}) {
    if (isClosed) return;
    switch (snapshot) {
      case PluginManagementLoadResultLoading():
        _actionGeneration++;
        emit(const PluginManagementState.loading());
      case PluginManagementLoadResultSupported(:final response, :final refreshError):
        final action = switch (state) {
          PluginManagementReady(:final action) => action,
          PluginManagementLoading() ||
          PluginManagementUnsupported() ||
          PluginManagementFailure() => const PluginManagementActionState.idle(),
        };
        emit(
          PluginManagementState.ready(
            response: response,
            refresh: switch (refreshError) {
              final error? => PluginManagementRefreshState.failed(error: error),
              null => const PluginManagementRefreshState.idle(),
            },
            action: action,
          ),
        );
      case PluginManagementLoadResultUnsupported():
        _actionGeneration++;
        emit(const PluginManagementState.unsupported());
      case PluginManagementLoadResultFailure(:final error):
        _actionGeneration++;
        emit(PluginManagementState.failure(error: error));
    }
  }

  @override
  Future<void> close() async {
    await _snapshotSubscription.cancel();
    return super.close();
  }
}
