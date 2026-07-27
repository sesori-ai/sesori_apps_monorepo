import "dart:async";

import "package:bloc/bloc.dart";

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

  Future<void> refresh() => _service.refresh();

  void dismissRefreshError() {
    if (isClosed) return;
    final current = state;
    if (current is! PluginManagementReady || current.refresh is! PluginManagementRefreshFailed) return;
    emit(current.copyWith(refresh: const PluginManagementRefreshState.idle()));
  }

  void _onSnapshot({required PluginManagementLoadResult snapshot}) {
    if (isClosed) return;
    switch (snapshot) {
      case PluginManagementLoadResultLoading():
        emit(const PluginManagementState.loading());
      case PluginManagementLoadResultSupported(:final response, :final refreshError):
        emit(
          PluginManagementState.ready(
            response: response,
            refresh: switch (refreshError) {
              final error? => PluginManagementRefreshState.failed(error: error),
              null => const PluginManagementRefreshState.idle(),
            },
            action: const PluginManagementActionState.idle(),
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
