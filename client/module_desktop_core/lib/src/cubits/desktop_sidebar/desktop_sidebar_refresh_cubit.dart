import "package:bloc/bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

class DesktopSidebarRefreshCubit._create({
  required final ProjectListCubit _projectListCubit,
  required final RecentSessionsCubit _recentSessionsCubit,
}) extends Cubit<DesktopSidebarRefreshState> {
  new({
    required ProjectListCubit projectListCubit,
    required RecentSessionsCubit recentSessionsCubit,
  }) : this._create(projectListCubit: projectListCubit, recentSessionsCubit: recentSessionsCubit);

  this : super(const DesktopSidebarRefreshIdle());

  Future<void> refresh() async {
    if (state is DesktopSidebarRefreshInProgress || _projectListCubit.state is! ProjectListLoaded) return;
    emit(const DesktopSidebarRefreshInProgress());
    try {
      final projectsSucceeded = await _projectListCubit.refreshProjects();
      if (isClosed) return;
      final currentProjects = _projectListCubit.state;
      final sessionsSucceeded = currentProjects is ProjectListLoaded
          ? await _recentSessionsCubit.refreshProjects(
              projectIds: currentProjects.projects.map((project) => project.id),
            )
          : false;
      if (isClosed) return;
      emit(
        projectsSucceeded && sessionsSucceeded
            ? const DesktopSidebarRefreshSucceeded()
            : const DesktopSidebarRefreshFailed(),
      );
    } on Object catch (error, stackTrace) {
      loge("Failed to refresh the desktop sidebar", error, stackTrace);
      if (!isClosed) emit(const DesktopSidebarRefreshFailed());
    }
  }
}

sealed class const DesktopSidebarRefreshState();

final class const DesktopSidebarRefreshIdle() extends DesktopSidebarRefreshState;

final class const DesktopSidebarRefreshInProgress() extends DesktopSidebarRefreshState;

final class const DesktopSidebarRefreshSucceeded() extends DesktopSidebarRefreshState;

final class const DesktopSidebarRefreshFailed() extends DesktopSidebarRefreshState;
