import "package:bloc/bloc.dart";

import "../../orchestration/desktop_sidebar_refresh_orchestrator.dart";

enum DesktopSidebarRefreshState() {
  idle,
  refreshing,
  succeeded,
  failed,
}

/// Presentation state only; inventory execution belongs to the workflow.
class DesktopSidebarRefreshCubit({required final DesktopSidebarRefreshOrchestrator _orchestrator})
    extends Cubit<DesktopSidebarRefreshState> {
  this : super(DesktopSidebarRefreshState.idle);

  Future<void> refresh() async {
    if (isClosed || state == DesktopSidebarRefreshState.refreshing) return;
    emit(DesktopSidebarRefreshState.refreshing);
    final outcome = await _orchestrator.refresh();
    if (isClosed) return;
    emit(switch (outcome) {
      DesktopSidebarRefreshOutcome.succeeded => DesktopSidebarRefreshState.succeeded,
      DesktopSidebarRefreshOutcome.failed => DesktopSidebarRefreshState.failed,
    });
  }
}
