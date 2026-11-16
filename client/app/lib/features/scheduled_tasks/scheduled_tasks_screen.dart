import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/mobile_composer_presentation_scope.dart";

/// Mobile-shell composition for the shared Scheduled page, pushed like the
/// other Settings pages.
class const ScheduledTasksScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ScheduledTasksView(
    createCubit: () => ScheduledTasksCubit(
      repository: getIt<ScheduledTaskRepository>(),
      connectionService: getIt<ConnectionService>(),
      timeZoneSource: getIt<DeviceTimeZoneSource>(),
    ),
    exit: ScheduledPageExit.back,
    onExit: () => _leave(context: context),
    onOpenTask: ({required taskId}) => context.pushRoute<void>(AppRoute.scheduledTaskDetail(taskId: taskId)),
    onNewTask: () => context.pushRoute<void>(const AppRoute.scheduledTaskEditor(taskId: null)),
  );
}

/// Mobile-shell composition for a scheduled task's own page.
class const ScheduledTaskDetailScreen({super.key, required final String taskId}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ScheduledTaskDetailView(
    createCubit: () => ScheduledTaskDetailCubit(
      repository: getIt<ScheduledTaskRepository>(),
      connectionService: getIt<ConnectionService>(),
      timeZoneSource: getIt<DeviceTimeZoneSource>(),
      taskId: taskId,
    ),
    onBack: () => _leave(context: context),
    onDeleted: () => _leave(context: context),
    onEdit: () => context.pushRoute<void>(AppRoute.scheduledTaskEditor(taskId: taskId)),
    onOpenSession: ({required projectId, required projectName, required sessionId}) => context.pushRoute<void>(
      AppRoute.sessionDetail(
        projectId: projectId,
        projectName: projectName,
        sessionId: sessionId,
        sessionTitle: null,
        readOnly: false,
        fromLaunch: false,
      ),
    ),
  );
}

/// Mobile-shell composition for the New task screen, or the same screen
/// editing [taskId].
class const ScheduledTaskEditorScreen({super.key, required final String? taskId}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ScheduledTaskEditorView(
    createCubit: () => createScheduledTaskEditorCubit(locator: getIt, taskId: taskId),
    createComposerCubit: ({required purpose}) => createNewSessionCubit(locator: getIt, purpose: purpose),
    onBack: () => _leave(context: context),
    onSaved: () => _leave(context: context),
    onOpenHarnessSettings: () => context.pushRoute(
      const AppRoute.settingsHarnesses(presentation: HarnessSettingsPresentation.modal),
    ),
    composerScopeBuilder: ({required projectId, required child}) => BlocProvider(
      create: (_) {
        final service = getIt<VoiceTranscriptionService>();
        return VoiceInputCubit(
          service: service,
          session: service.createSession(projectId: projectId, allowLive: true),
        );
      },
      child: MobileComposerPresentationScope(child: child),
    ),
    banner: ConnectionBanner.maybeFor(context),
    pageChrome: null,
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
