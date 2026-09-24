import "dart:async";

import "package:bloc/bloc.dart";

import "../../services/models/recent_sessions_entry.dart";
import "../../services/recent_session_inventory_service.dart";

/// Presentation adapter; the scoped service owns reads, live updates and data.
class RecentSessionsCubit({required final RecentSessionInventoryService inventoryService})
    extends Cubit<Map<String, RecentSessionsEntry>> {
  late final StreamSubscription<Map<String, RecentSessionsEntry>> _subscription;

  this : super(inventoryService.state.value) {
    _subscription = inventoryService.state.skip(1).listen(emit);
  }

  Future<void> retry({required String projectId}) => inventoryService.retry(projectId: projectId);

  /// Re-reads every admitted project, including ones whose read failed.
  Future<bool> refresh() => inventoryService.refresh();

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
