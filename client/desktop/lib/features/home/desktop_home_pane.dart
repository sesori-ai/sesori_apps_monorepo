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
import "../../core/widgets/desktop_transcript_width.dart";
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
        createNewSessionCubit: ({required projectId, required projectName}) =>
            createNewSessionCubit(locator: getIt, projectId: projectId, projectName: projectName),
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
  required final NewSessionCubit Function({required String projectId, required String? projectName})
  createNewSessionCubit,
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
      create: (_) => widget.createNewSessionCubit(projectId: picked.id, projectName: displayName),
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
        composerScopeBuilder: ({required child}) =>
            DesktopComposerPresentationScope(projectId: picked.id, child: child),
        // The desktop root owns its single connection banner.
        banner: null,
        pageChrome: NewSessionPageChrome(
          maxContentWidth: 760,
          transcriptWidth: desktopTranscriptWidth,
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
    final ActivitySlotInputs inputs = (
      projects: projects,
      deferredSessions: const {},
      hiddenSessionIds: context.select((PendingSessionArchiveCubit cubit) => cubit.state.hiddenIds),
      stickySessionId: null,
    );
    return ProjectLaunchRowsBuilder(
      initialRows: const {},
      slots: runningActivitySlots,
      slotInputs: inputs,
      builder: ({required context, required launchRows}) {
        final loc = context.loc;
        final projection = activityProjection(entries: context.watch<RecentSessionsCubit>().state, inputs: inputs);
        // A launch's session stays out of every section until it takes the
        // launching row's place in Running, or gives way to it in Needs you.
        final held = {for (final rows in launchRows.values) ...rows.heldSessionIds};
        List<_HomeRow> sessions(Iterable<SessionActivityItem> items) => [
          for (final item in items)
            if (!held.contains(item.entry.session.id))
              _HomeSessionRow(item: item, rowKey: launchRows[item.project.id]?.rowKeys[item.entry.session.id]),
        ];
        final sections = [
          (title: loc.desktopHomeNeedsYou, rows: sessions(projection.needsYou)),
          (
            title: loc.sessionListRunning,
            rows: [
              // A launch leads its project's running rows, where its session will run.
              for (final project in projects) ...[
                for (final launch in launchRows[project.id]?.placeholders ?? const <LaunchingSession>[])
                  _HomeLaunchRow(launch: launch, project: project),
                ...sessions(projection.running.where((item) => item.project.id == project.id)),
              ],
            ],
          ),
          (title: loc.desktopHomeRecent, rows: sessions(projection.recent).take(_recentLimit).toList()),
        ];
        // One list, headings included, so a section enters and leaves with its
        // rows and nothing below moves in one frame.
        return PregoAnimatedList<_HomeRow>(
          items: [
            for (final section in sections)
              if (section.rows.isNotEmpty) ...[_HomeHeading(title: section.title), ...section.rows],
          ],
          itemKey: (row) => switch (row) {
            _HomeHeading(:final title) => ValueKey(("heading", title)),
            _HomeSessionRow(:final item, :final rowKey) => ValueKey(rowKey ?? item.entry.session.id),
            _HomeLaunchRow(:final launch) => ValueKey(launch.launchId),
          },
          itemBuilder: (context, _, row) => switch (row) {
            _HomeHeading(:final title) => Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                PregoSpacing.xl,
                PregoSpacing.xl,
                PregoSpacing.xl,
                PregoSpacing.xs,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: context.prego.textTheme.textSm.medium.copyWith(color: context.prego.colors.textTertiary),
                ),
              ),
            ),
            _HomeSessionRow(item: (:final project, :final entry)) => ActivityTile(
              key: ValueKey("desktop-home-${entry.session.id}"),
              entry: entry,
              projectName: projectDisplayName(loc: loc, project: project),
              onOpen: () => onOpenSession(
                context: context,
                project: project,
                displayName: projectDisplayName(loc: loc, project: project),
                session: entry.session,
              ),
            ),
            _HomeLaunchRow(:final launch, :final project) => PendingActivityTile(
              key: ValueKey("desktop-home-launch-${launch.launchId}"),
              launch: launch,
              projectName: projectDisplayName(loc: loc, project: project),
            ),
          },
        );
      },
    );
  }
}

/// One entry of the home's sections: a heading, a session, or a launch.
sealed class const _HomeRow();

final class const _HomeHeading({required final String title}) extends _HomeRow;

final class const _HomeSessionRow({
  required final SessionActivityItem item,

  /// The launch whose row this session took the place of, kept as its key.
  required final String? rowKey,
}) extends _HomeRow;

final class const _HomeLaunchRow({required final LaunchingSession launch, required final ProjectSummary project})
    extends _HomeRow;

/// Recent stays a glance; the sidebar lists the rest.
const int _recentLimit = 5;
