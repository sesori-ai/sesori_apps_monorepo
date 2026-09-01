import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";

/// Desktop composition for the shared session inventory.
///
/// Session detail and new-session actions remain explicitly unavailable until
/// their planned slices land, so this screen does not render dead controls.
class const DesktopSessionListScreen({
  super.key,
  required final String projectId,
  required final String? projectName,
  required final VoidCallback onBack,
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
        onSessionTap: null,
        actionDispatcher: const SessionListActionDispatcher(onSessionDeleted: null),
        archivedEmptyState: const SessionArchivedEmptyState(artwork: null),
        onNewSession: null,
        onBack: onBack,
        connectionBanner: null,
      ),
    );
  }
}
