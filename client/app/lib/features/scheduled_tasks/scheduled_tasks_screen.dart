import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/routing/app_router.dart";

/// Mobile-shell composition for the shared Scheduled page, pushed like the
/// other Settings pages.
class const ScheduledTasksScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ScheduledTasksView(
    createCubit: () => ScheduledTasksCubit(
      repository: getIt<ScheduledTaskRepository>(),
      connectionService: getIt<ConnectionService>(),
    ),
    exit: ScheduledPageExit.back,
    onExit: () => _leave(context: context),
    onOpenTask: ({required taskId}) => context.pushRoute<void>(AppRoute.scheduledTaskDetail(taskId: taskId)),
  );
}

/// Mobile-shell composition for a scheduled task's own page.
class const ScheduledTaskDetailScreen({super.key, required final String taskId}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ScheduledTaskDetailView(
    createCubit: () => ScheduledTaskDetailCubit(
      repository: getIt<ScheduledTaskRepository>(),
      connectionService: getIt<ConnectionService>(),
      taskId: taskId,
    ),
    onBack: () => _leave(context: context),
    onDeleted: () => _leave(context: context),
  );
}

/// Pops the page, or goes home when a link opened it with nothing below.
void _leave({required BuildContext context}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.goRoute(const AppRoute.home());
  }
}
