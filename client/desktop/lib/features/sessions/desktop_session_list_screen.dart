import "dart:async";
import "dart:math" as math;

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
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
  SessionListQuickFilter _filter = SessionListQuickFilter.all;

  /// The toolbar's Refresh is in flight: the cubit refreshes silently, so the
  /// page shows the progress the pull gesture's own spinner used to.
  bool _refreshing = false;

  late final StreamSubscription<PendingSessionArchiveOutcome> _archiveOutcomes;

  @override
  void initState() {
    super.initState();
    // The bridge publishes no session event on archive, so a committed archive
    // refreshes the list for the Archived view to show the session at once.
    final sessions = context.read<SessionListCubit>();
    _archiveOutcomes = context.read<PendingSessionArchiveCubit>().outcomes.listen((outcome) {
      if (outcome is PendingSessionArchiveCommitted && outcome.session.projectID == sessions.projectId) {
        unawaited(sessions.refreshSessions());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_archiveOutcomes.cancel());
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await refreshSessionList(context);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DesktopSessionListScreen(:projectName, :onSessionTap, :onNewSession, :actionDispatcher) = widget;
    final loc = context.loc;
    final cubit = context.read<SessionListCubit>();
    final state = context.watch<SessionListCubit>().state;
    final loaded = state is SessionListLoaded ? state : null;
    final showArchived = loaded != null && loaded.filter != SessionListFilter.active;
    // The chips narrow the active list only; Archived shows everything it has.
    final filter = showArchived ? SessionListQuickFilter.all : _filter;
    // A session being archived leaves the list, and the counts, at once.
    final hidden = context.select((PendingSessionArchiveCubit cubit) => cubit.state.hiddenIds);
    final counted = loaded?.sessions.where((session) => !hidden.contains(session.id)).toList() ?? const <Session>[];
    final counts = {
      SessionListQuickFilter.all: counted.length,
      SessionListQuickFilter.running: counted
          .where((session) => loaded?.isSessionRunning(session: session) ?? false)
          .length,
      SessionListQuickFilter.unread: counted
          .where((session) => loaded?.isSessionUnseen(session: session) ?? false)
          .length,
    };

    return Scaffold(
      body: Column(
        children: [
          DesktopPageToolbar(
            leading: null,
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
                        if (loaded != null && !showArchived && loaded.sessions.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
                              child: Wrap(
                                spacing: PregoSpacing.md,
                                runSpacing: PregoSpacing.md,
                                children: [
                                  for (final MapEntry(key: value, value: count) in counts.entries)
                                    Semantics(
                                      toggled: filter == value,
                                      child: PregoButtonsSolid(
                                        key: Key("desktop-project-page-filter-${value.name}"),
                                        label: switch (value) {
                                          SessionListQuickFilter.all => loc.desktopProjectPageFilterAll(count),
                                          SessionListQuickFilter.running => loc.desktopProjectPageFilterRunning(count),
                                          SessionListQuickFilter.unread => loc.desktopProjectPageFilterUnread(count),
                                        },
                                        hierarchy: filter == value
                                            ? PregoButtonsSolidHierarchy.primaryAlt
                                            : PregoButtonsSolidHierarchy.secondary,
                                        size: PregoButtonsSolidSize.sm,
                                        onPressed: () => setState(() => _filter = value),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        SessionListContent(
                          projectName: projectName,
                          grouping: SessionListGrouping.timeline,
                          quickFilter: filter,
                          hiddenSessionIds: hidden,
                          onSessionTap: onSessionTap,
                          actionDispatcher: actionDispatcher,
                          archivedEmptyState: const SessionArchivedEmptyState(artwork: null),
                        ),
                        if (counts[filter] == 0 && loaded != null && loaded.sessions.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(PregoSpacing.x3l),
                              child: Text(
                                loc.desktopProjectPageFilterEmpty,
                                textAlign: TextAlign.center,
                                style: context.prego.textTheme.textSm.regular.copyWith(
                                  color: context.prego.colors.textTertiary,
                                ),
                              ),
                            ),
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
