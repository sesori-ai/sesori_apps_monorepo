import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";

/// Owns one project-scoped session inventory across narrow and split routes.
class const DesktopSessionListCubitProvider({
  super.key,
  required final String projectId,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SessionListCubit(
        sessionRepository: getIt<SessionRepository>(),
        sessionListService: getIt<SessionListService>(),
        projectRepository: getIt<ProjectRepository>(),
        connectionService: getIt<ConnectionService>(),
        sseEventTracker: getIt<SseEventTracker>(),
        sessionUnseenTracker: getIt<SessionUnseenTracker>(),
        projectViewingService: getIt<ProjectViewingService>(),
        routeSource: getIt<RouteSource>(),
        projectId: projectId,
        failureReporter: getIt<FailureReporter>(),
        catalogRescanService: getIt<CatalogRescanService>(),
      ),
      child: child,
    );
  }
}

/// Narrow desktop composition for the shared session inventory.
class const DesktopSessionListScreen({
  super.key,
  required final String? projectName,
  required final VoidCallback onBack,
  required final SessionOpenedCallback onSessionTap,
  required final VoidCallback onNewSession,
  required final SessionListActionDispatcher actionDispatcher,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SessionListScaffold(
      projectName: projectName,
      onSessionTap: onSessionTap,
      actionDispatcher: actionDispatcher,
      archivedEmptyState: const SessionArchivedEmptyState(artwork: null),
      onNewSession: onNewSession,
      onBack: onBack,
      connectionBanner: null,
    );
  }
}

/// Persistent left pane used by the wide desktop session split.
class const DesktopSessionListPane({
  super.key,
  required final String? projectName,
  required final String? selectedSessionId,
  required final VoidCallback onBack,
  required final SessionOpenedCallback onSessionTap,
  required final VoidCallback onNewSession,
  required final SessionListActionDispatcher actionDispatcher,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SessionListPanel(
      projectName: projectName,
      selectedSessionId: selectedSessionId,
      onSessionTap: onSessionTap,
      actionDispatcher: actionDispatcher,
      archivedEmptyState: const SessionArchivedEmptyState(artwork: null),
      onNewSession: onNewSession,
      onBack: onBack,
    );
  }
}
