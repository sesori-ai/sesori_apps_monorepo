import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

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

  /// Turns Sesori's tools on or off as a whole.
  Future<void> updateAgentTools({required bool enabled, required BridgeSettingsReady expectedState}) =>
      _updateAgentTools(
        expectedState: expectedState,
        target: const AgentToolsMasterSwitch(),
        enabled: enabled,
        save: () => _service.updateAgentTools(enabled: enabled),
      );

  /// Turns the tool group [id] on or off; it also changes while the master
  /// switch is off, and applies once it is on.
  Future<void> updateToolGroup({
    required String id,
    required bool enabled,
    required BridgeSettingsReady expectedState,
  }) => _updateAgentTools(
    expectedState: expectedState,
    target: AgentToolGroupSwitch(id: id),
    enabled: enabled,
    save: () => _service.updateToolGroup(id: id, enabled: enabled),
  );

  Future<void> _updateAgentTools({
    required BridgeSettingsReady expectedState,
    required AgentToolsSwitch target,
    required bool enabled,
    required Future<AgentToolsSettingsMutationResult> Function() save,
  }) async {
    if (_operationInProgress || !_connected || isClosed) return;
    final current = state;
    if (current is! BridgeSettingsReady || !identical(current, expectedState)) return;
    final agentTools = current.agentTools;
    if (agentTools == null) return;
    switch (agentTools.mutation) {
      case AgentToolsMutationInProgress() || AgentToolsMutationUncertain():
        return;
      case AgentToolsMutationIdle() || AgentToolsMutationFailed():
        break;
    }
    final currentEnabled = _enabledOf(agentTools: agentTools, target: target);
    if (currentEnabled == null || currentEnabled == enabled) return;

    _operationInProgress = true;
    final operationEpoch = _connectionEpoch;
    emit(
      _withAgentTools(
        state: current,
        agentTools: _withMutation(
          agentTools: agentTools,
          mutation: AgentToolsMutationInProgress(target: target),
        ),
      ),
    );
    try {
      final result = await save();
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      switch (result) {
        case AgentToolsSettingsMutationCommitted(:final enabled):
          emit(
            _withAgentTools(
              state: current,
              agentTools: _withSwitch(agentTools: agentTools, target: target, enabled: enabled),
            ),
          );
        case AgentToolsSettingsMutationFailure(:final error):
          emit(
            _withAgentTools(
              state: current,
              agentTools: _withMutation(
                agentTools: agentTools,
                mutation: AgentToolsMutationFailed(target: target, error: error),
              ),
            ),
          );
        case AgentToolsSettingsMutationUncertain():
          await _reconcileAgentTools(current: current, agentTools: agentTools, operationEpoch: operationEpoch);
      }
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      emit(
        _withAgentTools(
          state: current,
          agentTools: _withMutation(
            agentTools: agentTools,
            mutation: AgentToolsMutationFailed(target: target, error: ApiError.dartHttpClient(error)),
          ),
        ),
      );
    } finally {
      _finishOperation();
    }
  }

  Future<void> _reconcileAgentTools({
    required BridgeSettingsReady current,
    required AgentToolsSettings agentTools,
    required int operationEpoch,
  }) async {
    ApiError refreshError;
    try {
      final result = await _service.load();
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      if (result case BridgeSettingsLoadFailure(:final error)) {
        refreshError = error;
      } else {
        _publishLoad(result: result);
        return;
      }
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      refreshError = ApiError.dartHttpClient(error);
    }
    emit(
      _withAgentTools(
        state: current,
        agentTools: _withMutation(
          agentTools: agentTools,
          mutation: AgentToolsMutationUncertain(refreshError: refreshError),
        ),
      ),
    );
  }

  /// The switch's state, or null for a group the bridge did not list.
  static bool? _enabledOf({required AgentToolsSettings agentTools, required AgentToolsSwitch target}) {
    return switch (target) {
      AgentToolsMasterSwitch() => agentTools.enabled,
      AgentToolGroupSwitch(:final id) => agentTools.groups.where((group) => group.id == id).firstOrNull?.enabled,
    };
  }

  static AgentToolsSettings _withSwitch({
    required AgentToolsSettings agentTools,
    required AgentToolsSwitch target,
    required bool enabled,
  }) {
    return switch (target) {
      AgentToolsMasterSwitch() => AgentToolsSettings(
        enabled: enabled,
        groups: agentTools.groups,
        mutation: const AgentToolsMutationIdle(),
      ),
      AgentToolGroupSwitch(:final id) => AgentToolsSettings(
        enabled: agentTools.enabled,
        groups: [for (final group in agentTools.groups) group.id == id ? group.copyWith(enabled: enabled) : group],
        mutation: const AgentToolsMutationIdle(),
      ),
    };
  }

  static AgentToolsSettings _withMutation({
    required AgentToolsSettings agentTools,
    required AgentToolsMutationState mutation,
  }) => AgentToolsSettings(enabled: agentTools.enabled, groups: agentTools.groups, mutation: mutation);

  /// Follows internal pre-releases too, or stable releases only, from the
  /// bridge's next start.
  Future<void> updateReleaseTrack({required bool internalBuilds, required BridgeSettingsReady expectedState}) async {
    if (_operationInProgress || !_connected || isClosed) return;
    final current = state;
    if (current is! BridgeSettingsReady || !identical(current, expectedState)) return;
    final releaseTrack = current.releaseTrack;
    if (releaseTrack == null || releaseTrack.internalBuilds == internalBuilds) return;
    switch (releaseTrack.mutation) {
      case ReleaseTrackMutationInProgress() || ReleaseTrackMutationUncertain():
        return;
      case ReleaseTrackMutationIdle() || ReleaseTrackMutationFailed():
        break;
    }

    _operationInProgress = true;
    final operationEpoch = _connectionEpoch;
    final currentInternalBuilds = releaseTrack.internalBuilds;
    emit(
      _withReleaseTrack(
        state: current,
        internalBuilds: currentInternalBuilds,
        mutation: const ReleaseTrackMutationInProgress(),
      ),
    );
    try {
      final result = await _service.updateReleaseTrack(internalBuilds: internalBuilds);
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      switch (result) {
        case ReleaseTrackSettingsMutationCommitted(internalBuilds: final committed):
          emit(
            _withReleaseTrack(
              state: current,
              internalBuilds: committed,
              mutation: const ReleaseTrackMutationIdle(),
            ),
          );
        case ReleaseTrackSettingsMutationFailure(:final error):
          emit(
            _withReleaseTrack(
              state: current,
              internalBuilds: currentInternalBuilds,
              mutation: ReleaseTrackMutationFailed(error: error),
            ),
          );
        case ReleaseTrackSettingsMutationUncertain():
          await _reconcileReleaseTrack(
            current: current,
            currentInternalBuilds: currentInternalBuilds,
            operationEpoch: operationEpoch,
          );
      }
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      emit(
        _withReleaseTrack(
          state: current,
          internalBuilds: currentInternalBuilds,
          mutation: ReleaseTrackMutationFailed(error: ApiError.dartHttpClient(error)),
        ),
      );
    } finally {
      _finishOperation();
    }
  }

  Future<void> _reconcileReleaseTrack({
    required BridgeSettingsReady current,
    required bool currentInternalBuilds,
    required int operationEpoch,
  }) async {
    ApiError refreshError;
    try {
      final result = await _service.load();
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      if (result case BridgeSettingsLoadFailure(:final error)) {
        refreshError = error;
      } else {
        _publishLoad(result: result);
        return;
      }
    } on Object catch (error) {
      if (!_canPublish(operationEpoch: operationEpoch)) return;
      refreshError = ApiError.dartHttpClient(error);
    }
    emit(
      _withReleaseTrack(
        state: current,
        internalBuilds: currentInternalBuilds,
        mutation: ReleaseTrackMutationUncertain(refreshError: refreshError),
      ),
    );
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
            agentTools: switch (response) {
              BridgeSettingsResponse(agentToolsEnabled: final bool enabled, :final toolGroups)
                  when toolGroups.isNotEmpty =>
                AgentToolsSettings(enabled: enabled, groups: toolGroups, mutation: const AgentToolsMutationIdle()),
              BridgeSettingsResponse() => null,
            },
            // A track this app does not know is left out like a missing one.
            releaseTrack: switch (response.releaseTrack) {
              BridgeReleaseTrack.stable => const ReleaseTrackSettings(
                internalBuilds: false,
                mutation: ReleaseTrackMutationIdle(),
              ),
              BridgeReleaseTrack.internal => const ReleaseTrackSettings(
                internalBuilds: true,
                mutation: ReleaseTrackMutationIdle(),
              ),
              BridgeReleaseTrack.unknown || null => null,
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
      agentTools: state.agentTools,
      releaseTrack: state.releaseTrack,
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
      agentTools: state.agentTools,
      releaseTrack: state.releaseTrack,
    );
  }

  BridgeSettingsReady _withAgentTools({required BridgeSettingsReady state, required AgentToolsSettings agentTools}) {
    return BridgeSettingsReady(
      yoloEnabled: state.yoloEnabled,
      yoloMutation: state.yoloMutation,
      pluginWarmupMutation: state.pluginWarmupMutation,
      agentTools: agentTools,
      releaseTrack: state.releaseTrack,
    );
  }

  BridgeSettingsReady _withReleaseTrack({
    required BridgeSettingsReady state,
    required bool internalBuilds,
    required ReleaseTrackMutationState mutation,
  }) {
    return BridgeSettingsReady(
      yoloEnabled: state.yoloEnabled,
      yoloMutation: state.yoloMutation,
      pluginWarmupMutation: state.pluginWarmupMutation,
      agentTools: state.agentTools,
      releaseTrack: ReleaseTrackSettings(internalBuilds: internalBuilds, mutation: mutation),
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
