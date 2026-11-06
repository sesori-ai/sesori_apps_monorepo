import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "catalog_scan_failure_alerts.dart";
import "pending_archive_alerts.dart";
import "session_launch_failure_alerts.dart";

/// The signed-in session scope: the project inventory, the active sessions
/// window, the cubits every signed-in surface shares, and the alerts they
/// raise. Its [AllSessionsCubit] is the active list every all-projects
/// surface shares, created once read.
///
/// Product shells mount it under auth, above every route that lists or
/// launches sessions, so no route creates its own inventory or active window
/// (the archived route creates its own archived one). It outlives each page,
/// so an archive's Undo window and a launch's failure alert survive
/// navigation.
class const SessionScope({
  super.key,
  required final ProjectInventoryService Function() createProjectInventory,
  required final SessionWindowService Function({
    required AllSessionsMode mode,
    required ProjectInventoryService projectInventory,
  })
  createSessionWindow,
  required final SessionListRefreshService Function({
    required ProjectInventoryService projectInventory,
    required SessionWindowService window,
  })
  createRefreshService,
  required final SessionCleanupService sessionCleanupService,
  required final SessionLaunchService sessionLaunchService,
  required final ConnectionService connectionService,
  required final SessionListFilterTracker filterTracker,
  required final SseEventTracker sseEventTracker,
  required final SessionUnseenTracker sessionUnseenTracker,

  /// The navigator whose overlay shows the scope's alerts, so they share one
  /// alert slot with the pages' own alerts when the scope sits above that
  /// navigator. Null shows them on the nearest overlay.
  required final GlobalKey<NavigatorState>? alertNavigatorKey,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => RepositoryProvider<ProjectInventoryService>(
    create: (_) => createProjectInventory(),
    dispose: (inventory) => unawaited(inventory.dispose()),
    // The active sessions window every all-projects surface shares.
    child: RepositoryProvider<SessionWindowService>(
      create: (context) => createSessionWindow(
        mode: AllSessionsMode.active,
        projectInventory: context.read<ProjectInventoryService>(),
      ),
      dispose: (window) => unawaited(window.dispose()),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => ProjectListCubit(inventoryService: context.read<ProjectInventoryService>()),
          ),
          BlocProvider(
            create: (context) => SessionListRefreshCubit(
              service: createRefreshService(
                projectInventory: context.read<ProjectInventoryService>(),
                window: context.read<SessionWindowService>(),
              ),
            ),
          ),
          BlocProvider(create: (_) => PendingSessionArchiveCubit(cleanupService: sessionCleanupService)),
          BlocProvider(create: (_) => SessionLaunchCubit(launchService: sessionLaunchService)),
          BlocProvider(
            create: (context) => createAllSessionsCubit(
              context: context,
              filterTracker: filterTracker,
              sseEventTracker: sseEventTracker,
              sessionUnseenTracker: sessionUnseenTracker,
            ),
          ),
          // For each list's own launching rows.
          RepositoryProvider<SessionLaunchService>.value(value: sessionLaunchService),
          // For the folder browser, which every signed-in surface can open.
          RepositoryProvider<ConnectionService>.value(value: connectionService),
        ],
        child: PendingArchiveAlerts(
          navigatorKey: alertNavigatorKey,
          child: SessionLaunchFailureAlerts(
            navigatorKey: alertNavigatorKey,
            child: CatalogScanFailureAlerts(navigatorKey: alertNavigatorKey, child: child),
          ),
        ),
      ),
    ),
  );
}

/// An all-projects list over the nearest [SessionWindowService]: the scope's
/// active window, or a route's archived one.
AllSessionsCubit createAllSessionsCubit({
  required BuildContext context,
  required SessionListFilterTracker filterTracker,
  required SseEventTracker sseEventTracker,
  required SessionUnseenTracker sessionUnseenTracker,
}) => AllSessionsCubit(
  window: context.read<SessionWindowService>(),
  projectInventory: context.read<ProjectInventoryService>(),
  filterTracker: filterTracker,
  sseEventTracker: sseEventTracker,
  sessionUnseenTracker: sessionUnseenTracker,
);

/// A route's archived list under the enclosing [SessionScope]: its own
/// archived window, the refresh that reloads it, and its [AllSessionsCubit],
/// all disposed with the route. Below it they stand in for the scope's active
/// ones.
class const ArchivedSessionsScope({
  super.key,
  required final SessionWindowService Function({required ProjectInventoryService projectInventory}) createWindow,
  required final SessionListRefreshService Function({
    required ProjectInventoryService projectInventory,
    required SessionWindowService window,
  })
  createRefreshService,
  required final SessionListFilterTracker filterTracker,
  required final SseEventTracker sseEventTracker,
  required final SessionUnseenTracker sessionUnseenTracker,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => RepositoryProvider<SessionWindowService>(
    create: (context) => createWindow(projectInventory: context.read<ProjectInventoryService>()),
    dispose: (window) => unawaited(window.dispose()),
    child: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => SessionListRefreshCubit(
            service: createRefreshService(
              projectInventory: context.read<ProjectInventoryService>(),
              window: context.read<SessionWindowService>(),
            ),
          ),
        ),
        BlocProvider(
          create: (context) => createAllSessionsCubit(
            context: context,
            filterTracker: filterTracker,
            sseEventTracker: sseEventTracker,
            sessionUnseenTracker: sessionUnseenTracker,
          ),
        ),
      ],
      child: child,
    ),
  );
}
