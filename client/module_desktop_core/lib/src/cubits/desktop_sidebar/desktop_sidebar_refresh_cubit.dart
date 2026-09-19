import "package:bloc/bloc.dart";

import "../../services/desktop_sidebar_refresh_service.dart";

enum DesktopSidebarRefreshState() {
  idle,
  refreshing,
  succeeded,
  failed,
}

/// Presentation state only; inventory execution belongs to the workflow.
class DesktopSidebarRefreshCubit({required final DesktopSidebarRefreshService _service})
    extends Cubit<DesktopSidebarRefreshState> {
  this : super(DesktopSidebarRefreshState.idle);

  Future<void> refresh() async {
    if (isClosed || state == DesktopSidebarRefreshState.refreshing) return;
    emit(DesktopSidebarRefreshState.refreshing);
    final outcome = await _service.refresh();
    if (isClosed) return;
    emit(switch (outcome) {
      DesktopSidebarRefreshOutcome.succeeded => DesktopSidebarRefreshState.succeeded,
      DesktopSidebarRefreshOutcome.failed => DesktopSidebarRefreshState.failed,
    });
  }
}
