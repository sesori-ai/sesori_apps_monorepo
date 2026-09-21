import "dart:async";
import "dart:math" as math;

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/widgets/desktop_page_toolbar.dart";

/// Owns the full inventory only while the all-sessions page is mounted.
class const DesktopSessionListCubitProvider({
  super.key,
  required final String projectId,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => createSessionListCubit(
        mode: const SessionListMode.view(filter: SessionListFilter.active),
        locator: getIt,
        projectId: projectId,
      ),
      child: child,
    );
  }
}

/// The desktop project page: a toolbar over one timeline of the project's
/// sessions, in a column narrow enough to read from title to time.
class const DesktopSessionListScreen({
  super.key,
  required final String? projectName,
  required final SessionOpenedCallback onSessionTap,
  required final VoidCallback onNewSession,
  required final SessionListActionDispatcher actionDispatcher,
}) extends StatefulWidget {
  static const double maxContentWidth = 760;

  @override
  State<DesktopSessionListScreen> createState() => _DesktopSessionListScreenState();
}

class _DesktopSessionListScreenState() extends State<DesktopSessionListScreen> {
  /// The toolbar's Refresh is in flight: the cubit refreshes silently, so the
  /// page shows the progress the pull gesture's own spinner used to.
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await refreshSessionList(context);
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final DesktopSessionListScreen(:projectName, :onSessionTap, :onNewSession, :actionDispatcher) = widget;
    final loc = context.loc;
    final cubit = context.read<SessionListCubit>();
    final state = context.watch<SessionListCubit>().state;
    final loaded = state is SessionListLoaded ? state : null;
    final showArchived = loaded != null && loaded.filter != SessionListFilter.active;

    return Scaffold(
      body: Column(
        children: [
          DesktopPageToolbar(
            title: projectName ?? loc.sessionListTitle,
            subtitle: buildProjectNavSubtitle(context),
            actions: [
              Semantics(
                toggled: showArchived,
                child: PregoButtonsSolid(
                  key: const Key("desktop-project-page-archived"),
                  label: loc.desktopProjectPageArchived,
                  leadingIcon: TablerRegular.archive,
                  hierarchy: showArchived
                      ? PregoButtonsSolidHierarchy.primaryAlt
                      : PregoButtonsSolidHierarchy.secondary,
                  size: PregoButtonsSolidSize.sm,
                  onPressed: loaded == null ? null : cubit.toggleArchived,
                ),
              ),
              PregoButtonsSolid(
                key: const Key("desktop-project-page-new-session"),
                label: loc.sessionListNewSession,
                leadingIcon: TablerRegular.plus,
                hierarchy: PregoButtonsSolidHierarchy.primary,
                size: PregoButtonsSolidSize.sm,
                onPressed: onNewSession,
              ),
              // A mouse has no pull gesture, so the pull's two refreshes live here.
              PregoAnchorMenu(
                flat: true,
                menuWidth: 220,
                acquireOpenLease: null,
                entriesBuilder: () => [
                  PregoMenuItem(
                    title: loc.desktopProjectPageRefresh,
                    subtitle: null,
                    isSelected: false,
                    shortcutLabel: null,
                    leadingIcon: TablerRegular.refresh,
                    isEnabled: !_refreshing,
                    onTap: () => unawaited(_refresh()),
                  ),
                  PregoMenuItem(
                    title: loc.harnessManagementScan,
                    subtitle: null,
                    isSelected: false,
                    shortcutLabel: null,
                    leadingIcon: TablerRegular.radar_2,
                    onTap: cubit.startCatalogScan,
                  ),
                ],
                triggerBuilder: (context, openMenu) => IconButton(
                  key: const Key("desktop-project-page-more"),
                  tooltip: loc.sessionDetailMoreActions,
                  onPressed: loaded == null ? null : openMenu,
                  icon: const Icon(TablerRegular.dots, size: 18),
                ),
              ),
            ],
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => CustomScrollView(
                slivers: [
                  SliverPadding(
                    // The column is centred by padding, so the wheel and the
                    // scrollbar still belong to the whole pane.
                    padding: EdgeInsets.symmetric(
                      horizontal: math.max(0, (constraints.maxWidth - DesktopSessionListScreen.maxContentWidth) / 2),
                    ),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        if (_refreshing || (loaded != null && loaded.isRefreshing))
                          const SliverToBoxAdapter(child: LinearProgressIndicator()),
                        SliverToBoxAdapter(
                          child: CatalogScanRow(
                            scan: loaded?.catalogScan ?? const CatalogRescanState.idle(),
                            onCancel: cubit.cancelCatalogScan,
                            onDismiss: cubit.dismissCatalogScan,
                          ),
                        ),
                        SessionListContent(
                          projectName: projectName,
                          grouping: SessionListGrouping.timeline,
                          onSessionTap: onSessionTap,
                          actionDispatcher: actionDispatcher,
                          archivedEmptyState: const SessionArchivedEmptyState(artwork: null),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
