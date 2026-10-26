import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "catalog_scan_failure_alerts.dart";
import "pending_archive_alerts.dart";
import "session_launch_failure_alerts.dart";

/// The signed-in session scope: one pair of inventories, the cubits every
/// signed-in surface shares, and the alerts they raise. Its [AllSessionsCubit]
/// is the active list every all-projects surface shares, created once read.
///
/// Product shells mount it under auth, above every route that lists or
/// launches sessions, so no route creates its own inventory. It outlives each
/// page, so an archive's Undo window and a launch's failure alert survive
/// navigation.
class const SessionScope({
  super.key,
  required final RecentSessionInventoryService Function() createRecentSessionInventory,
  required final ProjectInventoryService Function() createProjectInventory,
  required final SessionListRefreshService Function({
    required ProjectInventoryService projectInventory,
    required RecentSessionInventoryService recentSessionInventory,
  })
  createRefreshService,
  required final SessionCleanupService sessionCleanupService,
  required final SessionLaunchService sessionLaunchService,
  required final ConnectionService connectionService,
  required final SessionListFilterTracker filterTracker,
  required final SessionListService sessionListService,

  /// The navigator whose overlay shows the scope's alerts, so they share one
  /// alert slot with the pages' own alerts when the scope sits above that
  /// navigator. Null shows them on the nearest overlay.
  required final GlobalKey<NavigatorState>? alertNavigatorKey,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => RepositoryProvider<RecentSessionInventoryService>(
    lazy: false,
    create: (_) => createRecentSessionInventory(),
    dispose: (inventory) => unawaited(inventory.dispose()),
    child: RepositoryProvider<ProjectInventoryService>(
      create: (_) => createProjectInventory(),
      dispose: (inventory) => unawaited(inventory.dispose()),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => ProjectListCubit(inventoryService: context.read<ProjectInventoryService>()),
          ),
          BlocProvider(
            create: (context) => SessionListRefreshCubit(
              service: createRefreshService(
                projectInventory: context.read<ProjectInventoryService>(),
                recentSessionInventory: context.read<RecentSessionInventoryService>(),
              ),
            ),
          ),
          BlocProvider(create: (_) => PendingSessionArchiveCubit(cleanupService: sessionCleanupService)),
          BlocProvider(create: (_) => SessionLaunchCubit(launchService: sessionLaunchService)),
          BlocProvider(
            create: (context) => createAllSessionsCubit(
              context: context,
              mode: AllSessionsMode.active,
              filterTracker: filterTracker,
              sessionListService: sessionListService,
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

/// An all-projects list over the enclosing [SessionScope]'s inventories: the
/// scope's own active list, or a route's archived one.
AllSessionsCubit createAllSessionsCubit({
  required BuildContext context,
  required AllSessionsMode mode,
  required SessionListFilterTracker filterTracker,
  required SessionListService sessionListService,
}) => AllSessionsCubit(
  mode: mode,
  recentInventory: context.read<RecentSessionInventoryService>(),
  projectInventory: context.read<ProjectInventoryService>(),
  filterTracker: filterTracker,
  sessionListService: sessionListService,
);
