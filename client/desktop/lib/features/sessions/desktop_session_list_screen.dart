import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";

/// Desktop composition for the shared session inventory.
///
/// New-session creation remains explicitly unavailable until its planned
/// slice lands, so this screen does not render a dead control.
class const DesktopSessionListScreen({
  super.key,
  required final String projectId,
  required final String? projectName,
  required final VoidCallback onBack,
  required final SessionOpenedCallback onSessionTap,
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
      child: SessionListScaffold(
        projectName: projectName,
        onSessionTap: onSessionTap,
        actionDispatcher: const SessionListActionDispatcher(onSessionDeleted: null),
        archivedEmptyState: const SessionArchivedEmptyState(artwork: null),
        onNewSession: null,
        onBack: onBack,
        connectionBanner: null,
      ),
    );
  }
}
