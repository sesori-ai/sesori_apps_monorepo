import "dart:async";
import "dart:math" as math;

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/widgets/desktop_composer_presentation_scope.dart";
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
/// sessions, in a column narrow enough to read from title to time. A project
/// with no sessions shows the new-session composer in the timeline's place.
class const DesktopSessionListScreen({
  super.key,
  required final String? projectName,

  /// Also opens a session the empty project's composer started.
  required final SessionOpenedCallback onSessionTap,
  required final SessionListActionDispatcher actionDispatcher,
  required final VoidCallback onOpenHarnessSettings,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DesktopSessionListView(
      projectName: projectName,
      onSessionTap: onSessionTap,
      actionDispatcher: actionDispatcher,
      createNewSessionCubit: ({required projectId}) => createNewSessionCubit(locator: getIt, projectId: projectId),
      onOpenHarnessSettings: onOpenHarnessSettings,
    );
  }
}

@visibleForTesting
class const DesktopSessionListView({
  super.key,
  required final String? projectName,
  required final SessionOpenedCallback onSessionTap,
  required final SessionListActionDispatcher actionDispatcher,
  required final NewSessionCubit Function({required String projectId}) createNewSessionCubit,
  required final VoidCallback onOpenHarnessSettings,
}) extends StatefulWidget {
  static const double maxContentWidth = 760;

  @override
  State<DesktopSessionListView> createState() => _DesktopSessionListViewState();
}

class _DesktopSessionListViewState() extends State<DesktopSessionListView> {
  /// The toolbar's Refresh is in flight: the cubit refreshes silently, so the
  /// page shows the progress the pull gesture's own spinner used to.
  bool _refreshing = false;

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
    final DesktopSessionListView(:projectName, :onSessionTap, :actionDispatcher) = widget;
    final loc = context.loc;
    final cubit = context.read<SessionListCubit>();
    final state = context.watch<SessionListCubit>().state;
    final loaded = state is SessionListLoaded ? state : null;
    final showArchived = loaded != null && loaded.filter != SessionListFilter.active;
    final isEmptyProject = loaded != null && !showArchived && loaded.sessions.isEmpty;
    return Scaffold(
      body: Column(
        children: [
          DesktopPageToolbar(
            breadcrumb: null,
            status: null,
            title: projectName ?? loc.sessionListTitle,
            subtitle: buildProjectNavSubtitle(context),
            actions: [
              Semantics(
                toggled: showArchived,
                child: PregoButtonsSolid(
                  key: const Key("desktop-project-page-archived"),
                  label: loc.desktopProjectPageArchived,
                  leadingIcon: TablerRegular.archive,
                  // Blue means on.
                  hierarchy: showArchived ? PregoButtonsSolidHierarchy.primary : PregoButtonsSolidHierarchy.secondary,
                  size: PregoButtonsSolidSize.sm,
                  onPressed: loaded == null ? null : cubit.toggleArchived,
                ),
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
                  icon: const Icon(TablerRegular.dots, size: PregoIconSize.md),
                ),
              ),
            ],
          ),
          Expanded(
            child: isEmptyProject
                ? BlocProvider(
                    create: (_) => widget.createNewSessionCubit(projectId: cubit.projectId),
                    child: NewSessionView(
                      projectId: cubit.projectId,
                      projectName: projectName,
                      // The page names its project; the header shows it without a picker.
                      projects: const [],
                      onProjectSelected: ({required projectId, required projectName}) {},
                      onBack: () {},
                      onOpenHarnessSettings: widget.onOpenHarnessSettings,
                      onSessionCreated: onSessionTap,
                      composerScopeBuilder: ({required child}) => DesktopComposerPresentationScope(child: child),
                      // The desktop root owns its single connection banner.
                      banner: null,
                      pageChrome: const NewSessionPageChrome(
                        topBar: SizedBox.shrink(),
                        maxContentWidth: DesktopSessionListView.maxContentWidth,
                        footer: null,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) => CustomScrollView(
                      slivers: [
                        SliverPadding(
                          // The column is centred by padding, so the wheel and the
                          // scrollbar still belong to the whole pane.
                          padding: EdgeInsets.symmetric(
                            horizontal: math.max(
                              0,
                              (constraints.maxWidth - DesktopSessionListView.maxContentWidth) / 2,
                            ),
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
                              SessionListFilteredContent(
                                projectName: projectName,
                                selectedSessionId: null,
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
