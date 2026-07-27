import "dart:async";

import "package:bloc/bloc.dart";

import "../../repositories/models/plugin_management_result.dart";
import "../../services/plugin_management_service.dart";
import "plugin_management_state.dart";

class PluginManagementCubit extends Cubit<PluginManagementState> {
  PluginManagementCubit({required PluginManagementService service})
    : _service = service,
      super(const PluginManagementState.loading()) {
    _snapshotSubscription = service.snapshots.listen(_onSnapshot);
  }

  final PluginManagementService _service;
  late final StreamSubscription<PluginManagementLoadResult> _snapshotSubscription;

  Future<void> refresh() => _service.refresh();

  void dismissRefreshError() {
    final current = state;
    if (current is! PluginManagementReady || current.refreshError == null) return;
    emit(current.copyWith(refreshError: null));
  }

  void _onSnapshot(PluginManagementLoadResult snapshot) {
    if (isClosed) return;
    switch (snapshot) {
      case PluginManagementLoadResultSupported(:final response, :final refreshError):
        emit(
          PluginManagementState.ready(
            response: response,
            refreshError: refreshError,
            actionStatus: PluginManagementActionStatus.idle,
            actingPluginId: null,
            pendingForceAction: null,
            actionError: null,
          ),
        );
      case PluginManagementLoadResultUnsupported():
        emit(const PluginManagementState.unsupported());
      case PluginManagementLoadResultFailure(:final error):
        emit(PluginManagementState.failure(error: error));
    }
  }

  @override
  Future<void> close() async {
    await _snapshotSubscription.cancel();
    return super.close();
  }
}
