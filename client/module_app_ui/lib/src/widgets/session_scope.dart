import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "catalog_scan_failure_alerts.dart";
import "pending_archive_alerts.dart";
import "session_launch_failure_alerts.dart";

/// The signed-in session scope: one pair of inventories, the cubits every
/// signed-in surface shares, and the alerts they raise.
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
          // For each list's own launching rows.
          RepositoryProvider<SessionLaunchService>.value(value: sessionLaunchService),
        ],
        child: PendingArchiveAlerts(
          child: SessionLaunchFailureAlerts(child: CatalogScanFailureAlerts(child: child)),
        ),
      ),
    ),
  );
}
