import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/widgets/desktop_composer_presentation_scope.dart";
import "../../core/widgets/desktop_sidebar.dart";
import "desktop_file_access_card.dart";

/// Home presentation consumes the cockpit's project inventory, never another list.
class const DesktopHomePane({
  super.key,

  /// Opens a session from the home's sections, and one the home just started.
  required final SidebarSessionOpenedCallback onOpenSession,

  /// Opens the project the empty home just added.
  required final ProjectOpenedCallback onOpenProject,
  required final VoidCallback onOpenHarnessSettings,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectListCubit>().state;
    if (state case ProjectListLoaded(:final projects) when projects.isNotEmpty) {
      return DesktopHomeStart(
        projects: projects,
        createNewSessionCubit: ({required projectId}) => createNewSessionCubit(locator: getIt, projectId: projectId),
        onOpenSession: onOpenSession,
        onOpenHarnessSettings: onOpenHarnessSettings,
      );
    }
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SafeArea(bottom: false, child: DesktopFileAccessCard())),
          SliverFillRemaining(
            hasScrollBody: false,
            child: SafeArea(
              child: switch (state) {
                ProjectListLoading() => Center(
                  child: Semantics(
                    label: context.loc.projectListLoadingSemantics,
                    child: const PregoAiLoader(size: 32),
                  ),
                ),
                ProjectListFailed(:final reason) => RemoteFailureView(
                  reason: reason,
                  title: context.loc.projectListErrorTitle,
                  retryLabel: context.loc.projectListRetry,
                  onRetry: () => context.read<ProjectListCubit>().retryLoadProjects(),
                ),
                ProjectListBridgeDisconnected() => BlocProvider(
                  create: (_) => BridgeIdentityCubit(
                    registeredBridgesService: getIt<RegisteredBridgesService>(),
                    connectionService: getIt<ConnectionService>(),
                  ),
                  child: Builder(
                    builder: (context) => DesktopBridgeRecoveryView(
                      bridge: switch (context.watch<BridgeIdentityCubit>().state) {
                        BridgeIdentityNamed(:final bridge) => bridge,
                        BridgeIdentityPending() || BridgeIdentityUnnamed() => null,
                      },
                      onStartBridge: context.read<BridgeControlCubit>().recoverConnection,
                    ),
                  ),
                ),
                ProjectListLoaded() => _DesktopHomeEmptyView(
                  onAddProject: () => _showAddProject(context: context, onOpenProject: onOpenProject),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  static void _showAddProject({required BuildContext context, required ProjectOpenedCallback onOpenProject}) {
    unawaited(
      showAddProjectDialog(
        context: context,
        cubit: context.read<ProjectListCubit>(),
        connectionService: getIt<ConnectionService>(),
        onProjectAdded: onOpenProject,
      ),
    );
  }
}

/// Desktop-owned supervised recovery shown for both unregistered and offline bridges.
class const DesktopBridgeRecoveryView({
  super.key,
  required final BridgeSummary? bridge,
  required final Future<void> Function() onStartBridge,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controlState = context.watch<BridgeControlCubit>().state;
    final bridge = this.bridge;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(PregoSpacing.x2l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // An illustration, not a glyph: no icon token applies.
              Icon(
                TablerRegular.device_laptop,
                size: 48,
                color: context.prego.colors.textTertiary,
              ),
              const SizedBox(height: PregoSpacing.lg),
              if (bridge != null) ...[
                Text(
                  bridge.name,
                  textAlign: TextAlign.center,
                  style: context.prego.textTheme.textLg.bold,
                ),
                const SizedBox(height: PregoSpacing.xs),
              ],
              Text(
                context.loc.projectsBridgeOfflineDisconnected,
                textAlign: TextAlign.center,
                style: context.prego.textTheme.textSm.regular.copyWith(
                  color: context.prego.colors.textSecondary,
                ),
              ),
              const SizedBox(height: PregoSpacing.x2l),
              Text(
                context.loc.projectsDesktopStartBridgeInfo,
                textAlign: TextAlign.center,
                style: context.prego.textTheme.textSm.regular,
              ),
              const SizedBox(height: PregoSpacing.xl),
              PregoButtonsSolid(
                label: context.loc.projectsDesktopStartBridge,
                leadingIcon: TablerRegular.player_play,
                hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                size: PregoButtonsSolidSize.xl,
                fullWidth: true,
                isLoading: controlState.activity == BridgeControlActivity.toggling,
                onPressed: controlState.activity.locksCommands ? null : () => unawaited(onStartBridge()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class const _DesktopHomeEmptyView({required final VoidCallback onAddProject}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(PregoSpacing.x2l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // An illustration, not a glyph: no icon token applies.
              Icon(
                TablerRegular.folder,
                size: 48,
                color: context.prego.colors.textTertiary,
              ),
              const SizedBox(height: PregoSpacing.lg),
              Text(
                context.loc.projectsEmptyMessage,
                textAlign: TextAlign.center,
                style: context.prego.textTheme.textMd.medium,
              ),
              const SizedBox(height: PregoSpacing.xl),
              PregoButtonsSolid(
                label: context.loc.projectsEmptyAddProject,
                leadingIcon: TablerRegular.folder_plus,
                hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                size: PregoButtonsSolidSize.xl,
                onPressed: onAddProject,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The home that starts work: the new-session composer for a picked project,
/// then what needs the user, what runs and what changed last.
@visibleForTesting
class const DesktopHomeStart({
  super.key,
  required final List<ProjectSummary> projects,
  required final NewSessionCubit Function({required String projectId}) createNewSessionCubit,
  required final SidebarSessionOpenedCallback onOpenSession,
  required final VoidCallback onOpenHarnessSettings,
}) extends StatefulWidget {
  @override
  State<DesktopHomeStart> createState() => _DesktopHomeStartState();
}

class _DesktopHomeStartState() extends State<DesktopHomeStart> {
  /// Null, or a project that has since gone, falls back to the first listed.
  String? _pickedProjectId;

  @override
  Widget build(BuildContext context) {
    final projects = widget.projects;
    // Held once shown: the list reorders as projects start running, and that
    // must not move the draft to another project.
    final picked = projects.where((project) => project.id == _pickedProjectId).firstOrNull ?? projects.first;
    _pickedProjectId = picked.id;
    final displayName = projectDisplayName(loc: context.loc, project: picked);
    // Keyed by project: a new pick gets its own cubit and draft, as the new
    // session page does when its route changes project.
    return BlocProvider(
      key: ValueKey("desktop-home-new-session-${picked.id}"),
      create: (_) => widget.createNewSessionCubit(projectId: picked.id),
      child: NewSessionView(
        projectId: picked.id,
        projectName: displayName,
        projects: projects,
        onProjectSelected: ({required projectId, required projectName}) => setState(() => _pickedProjectId = projectId),
        // The home is where Back would lead; there is nothing to leave.
        onBack: () {},
        onOpenHarnessSettings: widget.onOpenHarnessSettings,
        onSessionCreated: ({required session}) =>
            widget.onOpenSession(context: context, project: picked, displayName: displayName, session: session),
        composerScopeBuilder: ({required child}) => DesktopComposerPresentationScope(child: child),
        // The desktop root owns its single connection banner.
        banner: null,
        pageChrome: NewSessionPageChrome(
          maxContentWidth: 760,
          topBar: const SafeArea(bottom: false, child: DesktopFileAccessCard()),
          footer: _DesktopHomeSections(projects: projects, onOpenSession: widget.onOpenSession),
        ),
      ),
    );
  }
}

class const _DesktopHomeSections({
  required final List<ProjectSummary> projects,
  required final SidebarSessionOpenedCallback onOpenSession,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final projection = SessionActivityProjection.from(
      projects: projects,
      entries: context.watch<RecentSessionsCubit>().state,
      deferredSessions: const {},
      stickySessionId: null,
      hiddenSessionIds: context.select((PendingSessionArchiveCubit cubit) => cubit.state.hiddenIds),
    );
    final sections = [
      (title: loc.desktopHomeNeedsYou, items: projection.needsYou),
      (title: loc.sessionListRunning, items: projection.running),
      (title: loc.desktopHomeRecent, items: projection.recent.take(_recentLimit).toList()),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in sections)
          if (section.items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                PregoSpacing.xl,
                PregoSpacing.xl,
                PregoSpacing.xl,
                PregoSpacing.xs,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  section.title,
                  style: context.prego.textTheme.textSm.medium.copyWith(color: context.prego.colors.textTertiary),
                ),
              ),
            ),
            for (final item in section.items)
              ActivityTile(
                key: ValueKey("desktop-home-${item.entry.session.id}"),
                entry: item.entry,
                projectName: projectDisplayName(loc: loc, project: item.project),
                onOpen: () => onOpenSession(
                  context: context,
                  project: item.project,
                  displayName: projectDisplayName(loc: loc, project: item.project),
                  session: item.entry.session,
                ),
              ),
          ],
      ],
    );
  }
}

/// Recent stays a glance; the sidebar lists the rest.
const int _recentLimit = 5;
