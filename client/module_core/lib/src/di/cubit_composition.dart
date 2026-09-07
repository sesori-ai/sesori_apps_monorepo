import "package:get_it/get_it.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../cubits/new_session/new_session_cubit.dart";
import "../cubits/project_list/project_list_cubit.dart";
import "../cubits/session_detail/session_detail_cubit.dart";
import "../cubits/session_list/session_list_cubit.dart";
import "../platform/lifecycle_source.dart";
import "../platform/notification_canceller.dart";
import "../platform/route_source.dart";
import "../repositories/composer_draft_repository.dart";
import "../repositories/permission_repository.dart";
import "../repositories/project_repository.dart";
import "../repositories/session_repository.dart";
import "../services/catalog_rescan_service.dart";
import "../services/loaded_state_analytics_reporter.dart";
import "../services/new_session_options_service.dart";
import "../services/new_session_plugin_service.dart";
import "../services/new_session_selection_tracker.dart";
import "../services/product_analytics_service.dart";
import "../services/project_list_service.dart";
import "../services/project_viewing_service.dart";
import "../services/registered_bridges_service.dart";
import "../services/session_detail_load_service.dart";
import "../services/session_list_service.dart";
import "../services/session_unseen_tracker.dart";
import "../services/session_viewing_service.dart";
import "../services/sse_event_tracker.dart";

/// Shared cubit composition for the phone and desktop shells.
///
/// Each function returns a fresh cubit wired to the same collaborators every
/// shell resolves from its locator. Shells keep `BlocProvider(create:)`, route
/// ids, ownership and disposal, and surface-specific presentation; only the
/// collaborator list lives here, so the two shells cannot drift apart.

SessionDetailCubit createSessionDetailCubit({
  required GetIt locator,
  required String sessionId,
  required String projectId,
}) {
  return SessionDetailCubit(
    locator<ConnectionService>(),
    loadService: locator<SessionDetailLoadService>(),
    promptDispatcher: locator<SessionRepository>(),
    permissionRepository: locator<PermissionRepository>(),
    sessionViewingService: locator<SessionViewingService>(),
    projectViewingService: locator<ProjectViewingService>(),
    lifecycleSource: locator<LifecycleSource>(),
    composerDraftRepository: locator<ComposerDraftRepository>(),
    productAnalyticsService: locator<ProductAnalyticsService>(),
    sessionId: sessionId,
    projectId: projectId,
    notificationCanceller: locator<NotificationCanceller>(),
    failureReporter: locator<FailureReporter>(),
  );
}

ProjectListCubit createProjectListCubit({required GetIt locator}) {
  return ProjectListCubit(
    locator<ProjectRepository>(),
    locator<ConnectionService>(),
    locator<SseEventTracker>(),
    locator<RouteSource>(),
    projectListService: locator<ProjectListService>(),
    sessionUnseenTracker: locator<SessionUnseenTracker>(),
    registeredBridgesService: locator<RegisteredBridgesService>(),
    productAnalyticsService: locator<ProductAnalyticsService>(),
    loadedStateAnalyticsReporter: LoadedStateAnalyticsReporter.projectInventory(
      productAnalyticsService: locator<ProductAnalyticsService>(),
    ),
    failureReporter: locator<FailureReporter>(),
    catalogRescanService: locator<CatalogRescanService>(),
  );
}

SessionListCubit createSessionListCubit({required GetIt locator, required String projectId}) {
  return SessionListCubit(
    sessionRepository: locator<SessionRepository>(),
    sessionListService: locator<SessionListService>(),
    projectRepository: locator<ProjectRepository>(),
    connectionService: locator<ConnectionService>(),
    sseEventTracker: locator<SseEventTracker>(),
    sessionUnseenTracker: locator<SessionUnseenTracker>(),
    projectViewingService: locator<ProjectViewingService>(),
    routeSource: locator<RouteSource>(),
    projectId: projectId,
    failureReporter: locator<FailureReporter>(),
    catalogRescanService: locator<CatalogRescanService>(),
  );
}

NewSessionCubit createNewSessionCubit({required GetIt locator, required String projectId}) {
  return NewSessionCubit(
    connectionService: locator<ConnectionService>(),
    sessionRepository: locator<SessionRepository>(),
    newSessionPluginService: locator<NewSessionPluginService>(),
    newSessionOptionsService: locator<NewSessionOptionsService>(),
    projectRepository: locator<ProjectRepository>(),
    selectionTracker: locator<NewSessionSelectionTracker>(),
    composerDraftRepository: locator<ComposerDraftRepository>(),
    productAnalyticsService: locator<ProductAnalyticsService>(),
    projectId: projectId,
  );
}
