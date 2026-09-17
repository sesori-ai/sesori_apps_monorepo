import "package:bloc/bloc.dart";

import "../../services/desktop_sidebar_refresh_service.dart";

class DesktopSidebarRefreshCubit._create({
  required final DesktopSidebarRefreshOperation _refreshOperation,
}) extends Cubit<DesktopSidebarRefreshState> {
  new({required DesktopSidebarRefreshOperation refreshOperation}) : this._create(refreshOperation: refreshOperation);

  this : super(const DesktopSidebarRefreshIdle());

  Future<void> refresh() async {
    if (state is DesktopSidebarRefreshInProgress) return;
    emit(const DesktopSidebarRefreshInProgress());
    final result = await _refreshOperation.refresh();
    if (isClosed) return;
    emit(
      switch (result) {
        DesktopSidebarRefreshResult.succeeded => const DesktopSidebarRefreshSucceeded(),
        DesktopSidebarRefreshResult.failed => const DesktopSidebarRefreshFailed(),
      },
    );
  }
}

sealed class const DesktopSidebarRefreshState();

final class const DesktopSidebarRefreshIdle() extends DesktopSidebarRefreshState;

final class const DesktopSidebarRefreshInProgress() extends DesktopSidebarRefreshState;

final class const DesktopSidebarRefreshSucceeded() extends DesktopSidebarRefreshState;

final class const DesktopSidebarRefreshFailed() extends DesktopSidebarRefreshState;
