import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

abstract interface class DesktopSidebarRefreshOperation() {
  Future<DesktopSidebarRefreshResult> refresh();
}

/// Coordinates the two independent inventories behind one sidebar refresh.
final class DesktopSidebarRefreshOrchestrator._create({
  required final ProjectListCubit _projectListCubit,
  required final RecentSessionsCubit _recentSessionsCubit,
}) implements DesktopSidebarRefreshOperation {
  new({
    required ProjectListCubit projectListCubit,
    required RecentSessionsCubit recentSessionsCubit,
  }) : this._create(projectListCubit: projectListCubit, recentSessionsCubit: recentSessionsCubit);

  @override
  Future<DesktopSidebarRefreshResult> refresh() async {
    try {
      final projectsSucceeded = await _projectListCubit.refreshProjects();
      final List<ProjectSummary> projects = switch (_projectListCubit.state) {
        ProjectListLoaded(:final projects) => projects,
        ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => const <ProjectSummary>[],
      };
      final sessionsSucceeded = await _recentSessionsCubit.refreshProjects(
        projectIds: projects.map((project) => project.id),
      );
      return projectsSucceeded && sessionsSucceeded
          ? DesktopSidebarRefreshResult.succeeded
          : DesktopSidebarRefreshResult.failed;
    } on Object catch (error, stackTrace) {
      logw("Failed to refresh the desktop sidebar", error, stackTrace);
      return DesktopSidebarRefreshResult.failed;
    }
  }
}

enum DesktopSidebarRefreshResult() {
  succeeded,
  failed,
}
