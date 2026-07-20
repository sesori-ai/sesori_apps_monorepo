import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../repositories/models/plugin_management_result.dart";
import "../../services/plugin_management_service.dart";
import "plugin_management_state.dart";

class PluginManagementCubit extends Cubit<PluginManagementState> {
  final PluginManagementService _service;
  late final StreamSubscription<PluginManagementLoadResult> _snapshotSubscription;

  PluginManagementCubit({required PluginManagementService service})
    : _service = service,
      super(const PluginManagementState.loading()) {
    _snapshotSubscription = service.snapshots.listen(_onSnapshot);
  }

  Future<void> refresh() => _service.refresh();

  Future<void> enable({required String pluginId}) {
    return _runCommand(
      pluginId: pluginId,
      request: const PluginLifecycleCommandRequest.enable(),
      forceAction: null,
    );
  }

  Future<void> disable({required String pluginId}) {
    return _runCommand(
      pluginId: pluginId,
      request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
      forceAction: PluginManagementForceAction.disable,
    );
  }

  Future<void> restart({required String pluginId}) {
    return _runCommand(
      pluginId: pluginId,
      request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
      forceAction: PluginManagementForceAction.restart,
    );
  }

  Future<void> refreshPlugin({required String pluginId}) {
    return _runCommand(
      pluginId: pluginId,
      request: const PluginLifecycleCommandRequest.refresh(),
      forceAction: null,
    );
  }

  Future<void> applyIdleTimeoutToAll({required String input}) async {
    final idleTimeoutMins = _parseIdleTimeout(input: input, pluginId: null);
    if (idleTimeoutMins == null) return;
    await _runMutation(
      pluginId: null,
      mutation: () => _service.updateIdleTimeout(
        request: PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: idleTimeoutMins),
      ),
      forceAction: null,
    );
  }

  Future<void> setIdleTimeoutOverride({required String pluginId, required String input}) async {
    final idleTimeoutMins = _parseIdleTimeout(input: input, pluginId: pluginId);
    if (idleTimeoutMins == null) return;
    await _runMutation(
      pluginId: pluginId,
      mutation: () => _service.updateIdleTimeout(
        request: PluginIdleTimeoutUpdateRequest.setOverride(
          pluginId: pluginId,
          idleTimeoutMins: idleTimeoutMins,
        ),
      ),
      forceAction: null,
    );
  }

  Future<void> clearIdleTimeoutOverride({required String pluginId}) {
    return _runMutation(
      pluginId: pluginId,
      mutation: () => _service.updateIdleTimeout(
        request: PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: pluginId),
      ),
      forceAction: null,
    );
  }

  Future<void> confirmForce() async {
    final current = state;
    if (current is! PluginManagementReady || current.actionStatus == PluginManagementActionStatus.inProgress) return;

    final pluginId = current.actingPluginId;
    final action = current.pendingForceAction;
    if (pluginId == null || action == null) return;

    await _runCommand(
      pluginId: pluginId,
      request: switch (action) {
        PluginManagementForceAction.disable => const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
        PluginManagementForceAction.restart => const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.force),
      },
      forceAction: null,
    );
  }

  void dismissActionError() {
    final current = state;
    if (current is! PluginManagementReady || current.actionStatus == PluginManagementActionStatus.inProgress) return;
    emit(
      current.copyWith(
        actionStatus: PluginManagementActionStatus.idle,
        actingPluginId: null,
        pendingForceAction: null,
        actionError: null,
      ),
    );
  }

  Future<void> _runCommand({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
    required PluginManagementForceAction? forceAction,
  }) {
    return _runMutation(
      pluginId: pluginId,
      mutation: () => _service.command(pluginId: pluginId, request: request),
      forceAction: forceAction,
    );
  }

  Future<void> _runMutation({
    required String? pluginId,
    required Future<PluginManagementMutationResult> Function() mutation,
    required PluginManagementForceAction? forceAction,
  }) async {
    final current = state;
    if (current is! PluginManagementReady || current.actionStatus == PluginManagementActionStatus.inProgress) return;

    _emitAction(
      current: current,
      status: PluginManagementActionStatus.inProgress,
      pluginId: pluginId,
      pendingForceAction: null,
      error: null,
    );
    final result = await mutation();
    if (isClosed) return;

    switch (result) {
      case PluginManagementMutationSuccess(:final response):
        emit(
          PluginManagementState.ready(
            response: response,
            actionStatus: PluginManagementActionStatus.idle,
            actingPluginId: null,
            pendingForceAction: null,
            actionError: null,
          ),
        );
      case PluginManagementMutationNotFound():
        _emitMutationFailure(
          pluginId: pluginId,
          error: const PluginManagementActionError.notFound(),
          pendingForceAction: null,
        );
      case PluginManagementMutationConflict(:final conflict):
        final pending = forceAction != null && conflict.pluginId == pluginId && _isForceable(conflict)
            ? forceAction
            : null;
        _emitMutationFailure(
          pluginId: pluginId,
          error: PluginManagementActionError.conflict(conflict: conflict),
          pendingForceAction: pending,
        );
      case PluginManagementMutationFailure(:final error):
        _emitMutationFailure(
          pluginId: pluginId,
          error: PluginManagementActionError.request(error: error),
          pendingForceAction: null,
        );
    }
  }

  int? _parseIdleTimeout({required String input, required String? pluginId}) {
    final value = int.tryParse(input.trim());
    if (value != null) return value;

    final current = state;
    if (current is PluginManagementReady && current.actionStatus != PluginManagementActionStatus.inProgress) {
      _emitAction(
        current: current,
        status: PluginManagementActionStatus.failure,
        pluginId: pluginId,
        pendingForceAction: null,
        error: const PluginManagementActionError.invalidIdleTimeout(),
      );
    }
    return null;
  }

  bool _isForceable(PluginLifecycleConflict conflict) {
    if (conflict.reasons.isEmpty) return false;
    return conflict.reasons.every(
      (reason) => switch (reason) {
        PluginLifecycleConflictReason.inFlight ||
        PluginLifecycleConflictReason.busy ||
        PluginLifecycleConflictReason.workStateUnknown => true,
        PluginLifecycleConflictReason.transitioning || PluginLifecycleConflictReason.notEnabled => false,
      },
    );
  }

  void _emitMutationFailure({
    required String? pluginId,
    required PluginManagementActionError error,
    required PluginManagementForceAction? pendingForceAction,
  }) {
    final current = state;
    if (current is! PluginManagementReady) return;
    _emitAction(
      current: current,
      status: PluginManagementActionStatus.failure,
      pluginId: pluginId,
      pendingForceAction: pendingForceAction,
      error: error,
    );
  }

  void _emitAction({
    required PluginManagementReady current,
    required PluginManagementActionStatus status,
    required String? pluginId,
    required PluginManagementForceAction? pendingForceAction,
    required PluginManagementActionError? error,
  }) {
    if (isClosed) return;
    emit(
      current.copyWith(
        actionStatus: status,
        actingPluginId: pluginId,
        pendingForceAction: pendingForceAction,
        actionError: error,
      ),
    );
  }

  void _onSnapshot(PluginManagementLoadResult snapshot) {
    if (isClosed) return;
    switch (snapshot) {
      case PluginManagementSupported(:final response):
        final current = state;
        final preserveAction =
            current is PluginManagementReady &&
            (current.actionStatus == PluginManagementActionStatus.inProgress || current.pendingForceAction != null);
        emit(
          PluginManagementState.ready(
            response: response,
            actionStatus: preserveAction ? current.actionStatus : PluginManagementActionStatus.idle,
            actingPluginId: preserveAction ? current.actingPluginId : null,
            pendingForceAction: preserveAction ? current.pendingForceAction : null,
            actionError: preserveAction ? current.actionError : null,
          ),
        );
      case PluginManagementUnsupported():
        emit(const PluginManagementState.unsupported());
      case PluginManagementLoadFailure(:final error):
        emit(PluginManagementState.failure(error: error));
    }
  }

  @override
  Future<void> close() async {
    await _snapshotSubscription.cancel();
    return super.close();
  }
}
