import "dart:async";

import "package:flutter/foundation.dart" show setEquals;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/list_search_field.dart";
import "../../widgets/project_launch_rows_builder.dart";
import "../../widgets/remote_failure_view.dart";
import "../project_list/project_path_labels.dart";
import "../session_detail/widgets/transcript_motion.dart";
import "session_date_label.dart";
import "session_list_action_dispatcher.dart";
import "session_list_headings.dart";
import "session_tile.dart";

typedef AllSessionsRowOpenedCallback = void Function({required AllSessionsRow row});

/// Builds the action-mode [SessionListCubit] a row's swipe and menu actions
/// run on.
typedef ActionSessionListCubitFactory = SessionListCubit Function({
  required String projectId,
  required Session session,
});

/// The page, as a sliver, for a computer that is not connected.
typedef AllSessionsDisconnectedBuilder = Widget Function({
  required BuildContext context,
  required ProjectListBridgeDisconnected state,
});

/// The [AllSessionsCubit] list across projects, as one sliver: its rows under
/// date headings, in the cubit's order. Each row names its project unless the
/// list is filtered to one (D3).
///
/// The project list comes first: while it cannot load, or the computer is not
/// connected, the list shows that in place of its rows.
///
/// The active list adds the All / Running / Unread chips and every project's
/// launches leading Today. It leaves out the sessions inside an archive's Undo
/// window and those a launch still holds.
///
/// A row's actions run on its own action-mode [SessionListCubit], built only
/// once a swipe or menu needs it.
class const AllSessionsList({
  super.key,
  required final AllSessionsRowOpenedCallback onSessionTap,
  required final SessionListActionDispatcher actionDispatcher,
  required final ActionSessionListCubitFactory createActionCubit,

  /// The session a content pane beside the list shows, highlighted.
  required final String? selectedSessionId,
  required final AllSessionsDisconnectedBuilder disconnectedBuilder,

  /// Shown once the projects have loaded, when there are no sessions.
  required final Widget emptyState,

  /// Heads the list under its search field, such as the sidebar's project
  /// switcher (D4), whether or not there are sessions.
  required final Widget? header,

  /// Extra room under the last row, for a button floating over the list's
  /// end, such as the phone home's New session.
  required final double endClearance,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => switch (context.watch<ProjectListCubit>().state) {
    ProjectListFailed(:final reason) => SliverFillRemaining(
      hasScrollBody: false,
      child: RemoteFailureView(
        reason: reason,
        title: context.loc.projectListErrorTitle,
        retryLabel: context.loc.projectListRetry,
        onRetry: () => context.read<ProjectListCubit>().retryLoadProjects(),
      ),
    ),
    final ProjectListBridgeDisconnected disconnected => disconnectedBuilder(context: context, state: disconnected),
    ProjectListLoading() || ProjectListLoaded() => switch (context.read<AllSessionsCubit>().mode) {
      AllSessionsMode.active => _ActiveSessions(list: this),
      AllSessionsMode.archived => _Sessions(list: this, launchRows: const {}, hiddenSessionIds: const {}),
    },
  };
}

class const _ActiveSessions({required final AllSessionsList list}) extends StatefulWidget {
  @override
  State<_ActiveSessions> createState() => _ActiveSessionsState();
}

class _ActiveSessionsState() extends State<_ActiveSessions> {
  Set<String> _hiddenSessionIds = const {};

  @override
  Widget build(BuildContext context) => ProjectLaunchRowsBuilder(
    initialRows: const {},
    builder: ({required context, required launchRows}) {
      final hidden = {
        ...context.select((PendingSessionArchiveCubit cubit) => cubit.state.hiddenIds),
        for (final rows in launchRows.values) ...rows.heldSessionIds,
      };
      if (!setEquals(hidden, _hiddenSessionIds)) {
        _hiddenSessionIds = hidden;
        final sessions = context.read<AllSessionsCubit>();
        // Not during a build. Until the cubit follows, the rows below leave
        // these sessions out themselves; its counts follow a frame later.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) sessions.setHiddenSessionIds(sessionIds: hidden);
        });
      }
      return _Sessions(list: widget.list, launchRows: launchRows, hiddenSessionIds: hidden);
    },
  );
}

/// One item of the list: a session, or a launch leading Today.
sealed class const _Item();

final class const _SessionItem({required final AllSessionsRow row}) extends _Item;

final class const _LaunchItem({required final LaunchingSession launch}) extends _Item;

class const _Sessions({
  required final AllSessionsList list,
  required final Map<String, LaunchRows> launchRows,
  required final Set<String> hiddenSessionIds,
}) extends StatefulWidget {
  @override
  State<_Sessions> createState() => _SessionsState();
}

class _SessionsState() extends State<_Sessions> with SingleTickerProviderStateMixin {
  /// The hand-off from the loading skeleton to the first rows or the empty
  /// state: they fade in where the skeleton stood while it fades out over
  /// them. Complete at rest, so later updates show as they always do.
  late final AnimationController _handOff = AnimationController(
    vsync: this,
    duration: transcriptMotionDuration,
    value: 1,
  );
  late final CurvedAnimation _contentOpacity = CurvedAnimation(parent: _handOff, curve: transcriptMotionCurve);
  late final CurvedAnimation _skeletonOpacity = CurvedAnimation(
    parent: ReverseAnimation(_handOff),
    curve: transcriptMotionReverseCurve,
  );

  /// Keeps the one skeleton, with its appearance delay and sheen, as it moves
  /// from its own place onto the content that replaces it.
  final GlobalKey _skeletonKey = GlobalKey(debugLabel: "all-sessions-skeleton");
  bool _wasLoading = false;

  @override
  void initState() {
    super.initState();
    _handOff.addStatusListener((status) {
      // The faded skeleton leaves the tree.
      if (status.isCompleted) setState(() {});
    });
  }

  @override
  void dispose() {
    _contentOpacity.dispose();
    _skeletonOpacity.dispose();
    _handOff.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _Sessions(:list, :launchRows, :hiddenSessionIds) = widget;
    final loc = context.loc;
    final prego = context.prego;
    final cubit = context.read<AllSessionsCubit>();
    final state = context.watch<AllSessionsCubit>().state;
    final now = DateTime.now();
    // The list's bottom breathing room collapses with its last row, which
    // rests above the home indicator and anything floating there.
    final endPadding = 8 + MediaQuery.paddingOf(context).bottom + list.endClearance;
    final searching = state.query.trim().isNotEmpty;
    // A launching row has no title to match, and is neither running nor
    // unread yet, so a search or a chip hides it.
    final launches = searching || state.quickFilter != SessionListQuickFilter.all
        ? const <LaunchingSession>[]
        : [
            for (final MapEntry(key: projectId, value: rows) in launchRows.entries)
              if (state.projectId == null || state.projectId == projectId) ...rows.placeholders,
          ];
    // Only a still-unarchived session hides, as on every list.
    final rows = state.rows.where(
      (row) => row.session.time?.archived != null || !hiddenSessionIds.contains(row.session.id),
    );
    final entries = groupUnderHeadings<_Item>(
      items: [
        for (final launch in launches) _LaunchItem(launch: launch),
        for (final row in rows) _SessionItem(row: row),
      ],
      headingOf: (item) => switch (item) {
        // A launch is the newest running thing, so it leads Today.
        _LaunchItem() => sessionDateLabel(date: now, now: now, loc: loc),
        // Only the archived mode lists archived rows, and it sorts them by
        // archive time alone, running or not.
        _SessionItem(:final row) => sessionListHeading(
          timestamp: row.session.time?.archived ?? row.session.time?.updated,
          isRunning: row.isRunning && row.session.time?.archived == null,
          now: now,
          loc: loc,
        ),
      },
    );
    // A launching row counts, so the search field and chips are already in
    // place when a first session takes its row.
    final hasSessions = state.counts.all > 0 || launches.isNotEmpty || searching;
    final loading = state.isLoading && entries.isEmpty;
    if (_wasLoading && !loading && !context.isReducedMotion) {
      _handOff.value = 0;
      // Timed from the next frame: this one mounts the content and can be
      // slow enough to use up the whole fade.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handOff.forward();
      });
    }
    _wasLoading = loading;
    // The skeleton fades out from the top of the first box under the header,
    // where it stood. At most one box holds it.
    final skeletonLeaving = !loading && !_handOff.isCompleted;
    final settled = !state.isLoading && state.failures.isEmpty && entries.isEmpty;
    final note = switch (settled) {
      false => null,
      true when searching => loc.listSearchNoMatches,
      // Unsearched, All can only be empty while its last session hides.
      true when state.counts.all > 0 && state.quickFilter != SessionListQuickFilter.all => loc.sessionListFilterEmpty,
      true => null,
    };

    return SliverMainAxisGroup(
      slivers: [
        if (hasSessions)
          SliverToBoxAdapter(
            child: _arriving(
              holdsSkeleton: skeletonLeaving && list.header == null,
              child: ListSearchField(
                query: state.query,
                hintText: loc.sessionListSearchHint,
                autofocus: false,
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
                onChanged: (query) => cubit.setQuery(query: query),
              ),
            ),
          ),
        if (list.header case final header?) SliverToBoxAdapter(child: header),
        if (cubit.mode == AllSessionsMode.active && hasSessions)
          SliverToBoxAdapter(
            child: _arriving(
              holdsSkeleton: skeletonLeaving && list.header != null,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
                child: Wrap(
                  spacing: PregoSpacing.md,
                  runSpacing: PregoSpacing.md,
                  children: [
                    for (final filter in SessionListQuickFilter.values)
                      Semantics(
                        toggled: state.quickFilter == filter,
                        child: PregoButtonsSolid(
                          key: Key("session-list-filter-${filter.name}"),
                          label: switch (filter) {
                            SessionListQuickFilter.all => loc.sessionListFilterAll(state.counts.all),
                            SessionListQuickFilter.running => loc.sessionListFilterRunning(state.counts.running),
                            SessionListQuickFilter.unread => loc.sessionListFilterUnread(state.counts.unread),
                          },
                          hierarchy: state.quickFilter == filter
                              ? PregoButtonsSolidHierarchy.primaryAlt
                              : PregoButtonsSolidHierarchy.secondary,
                          size: PregoButtonsSolidSize.sm,
                          onPressed: () => cubit.setQuickFilter(filter: filter),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        for (final failure in state.failures)
          SliverToBoxAdapter(
            key: ValueKey("all-sessions-failure-${failure.project.id}"),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      loc.allSessionsProjectFailed(projectDisplayName(loc: loc, project: failure.project)),
                      style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
                    ),
                  ),
                  PregoButtonsSolid(
                    label: loc.sessionListRetry,
                    hierarchy: PregoButtonsSolidHierarchy.secondary,
                    size: PregoButtonsSolidSize.sm,
                    onPressed: () => unawaited(cubit.retry(projectId: failure.project.id)),
                  ),
                ],
              ),
            ),
          ),
        if (loading)
          SliverToBoxAdapter(child: _skeleton(context: context))
        else
          // Mounted with the first rows at full size, which fade in with the
          // hand-off. It stays mounted when the list becomes empty, giving the
          // final removed row time to close before the empty state settles in.
          SliverFadeTransition(
            opacity: _contentOpacity,
            sliver: PregoAnimatedSliverList<SessionListEntry<_Item>>(
              items: entries,
              itemKey: (entry) => switch (entry) {
                final SessionListHeadingEntry<_Item> heading => heading.key,
                SessionListItemEntry(item: _LaunchItem(:final launch)) => ValueKey<Object>(launch.launchId),
                // A session that took a launch's place keeps that row's key.
                SessionListItemEntry(item: _SessionItem(:final row)) => ValueKey<Object>(
                  launchRows[row.project.id]?.rowKeys[row.session.id] ?? (row.project.id, row.session.id),
                ),
              },
              itemBuilder: (_, index, entry) => switch (entry) {
                SessionListHeadingEntry(:final heading) => SessionListHeading(heading: heading, isFirst: index == 0),
                SessionListItemEntry(item: _LaunchItem(:final launch)) => _launchRowSettling(
                  context: context,
                  launching: true,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(bottom: index == entries.length - 1 ? endPadding : 0),
                    child: PendingSessionLaunchTile(launch: launch),
                  ),
                ),
                SessionListItemEntry(item: _SessionItem(:final row)) => _sessionRow(
                  context: context,
                  row: row,
                  bottomPadding: index == entries.length - 1 ? endPadding : 0,
                  tookLaunchRow: launchRows[row.project.id]?.rowKeys.containsKey(row.session.id) ?? false,
                  // A "No project" session has no project to name.
                  labelsProject: state.projectId == null && row.project.id != state.scratchProjectId,
                ),
              },
            ),
          ),
        if (note != null)
          SliverFadeTransition(
            opacity: _contentOpacity,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(PregoSpacing.x3l),
                child: Text(
                  note,
                  textAlign: TextAlign.center,
                  style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textTertiary),
                ),
              ),
            ),
          ),
        if (settled && !hasSessions)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _arriving(holdsSkeleton: skeletonLeaving, child: list.emptyState),
          ),
      ],
    );
  }

  Widget _skeleton({required BuildContext context}) =>
      PregoSkeletonList(key: _skeletonKey, semanticLabel: context.loc.sessionListLoadingSemantics);

  /// [child], fading in with the hand-off. While it [holdsSkeleton], the
  /// skeleton fades out over it and what follows, hanging from its top
  /// without taking room.
  Widget _arriving({required bool holdsSkeleton, required Widget child}) => Stack(
    fit: StackFit.passthrough,
    clipBehavior: Clip.none,
    children: [
      FadeTransition(opacity: _contentOpacity, child: child),
      if (holdsSkeleton)
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: FadeTransition(
                opacity: _skeletonOpacity,
                child: _skeleton(context: context),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _sessionRow({
    required BuildContext context,
    required AllSessionsRow row,
    required double bottomPadding,
    required bool tookLaunchRow,
    required bool labelsProject,
  }) {
    final list = widget.list;
    final dispatcher = list.actionDispatcher;
    final tile = Padding(
      padding: EdgeInsetsDirectional.only(bottom: bottomPadding),
      child: BlocProvider(
        create: (_) => list.createActionCubit(projectId: row.project.id, session: row.session),
        child: Builder(
          builder: (rowContext) {
            SessionListCubit actions() =>
                rowContext.read<SessionListCubit>()..updateActionSession(session: row.session);
            // Actions run against the list's context, not the row's: a delete
            // unmounts the row before its follow-ups run.
            return SessionTile(
              session: row.session,
              projectLabel: labelsProject ? projectDisplayName(loc: context.loc, project: row.project) : null,
              isArchived: row.session.time?.archived != null,
              isRunning: row.isRunning,
              unseen: row.isUnseen,
              selected: list.selectedSessionId == row.session.id,
              awaitingInput: row.isAwaitingInput,
              isRetrying: row.isRetrying,
              backgroundTaskCount: row.backgroundTaskCount,
              onTap: () => list.onSessionTap(row: row),
              menuEntries: () => dispatcher.sessionMenuEntries(
                context: context,
                cubit: actions(),
                session: row.session,
                readEntry: SessionReadMenuEntry.toggle,
              ),
              onArchive: () =>
                  dispatcher.handleSessionArchive(context: context, cubit: actions(), session: row.session),
              onDelete: () => dispatcher.handleSessionDelete(context: context, cubit: actions(), session: row.session),
              onToggleUnread: () =>
                  dispatcher.handleSessionToggleUnread(context: context, cubit: actions(), session: row.session),
            );
          },
        ),
      ),
    );
    return tookLaunchRow ? _launchRowSettling(context: context, launching: false, child: tile) : tile;
  }
}

/// A launching row and the session row that takes its place share one list
/// item, so the change cross-fades in place rather than collapsing one row and
/// opening another.
Widget _launchRowSettling({required BuildContext context, required bool launching, required Widget child}) =>
    AnimatedSwitcher(
      duration: prefersReducedMotion(context) ? Duration.zero : _settleDuration,
      child: KeyedSubtree(key: ValueKey(launching), child: child),
    );

const Duration _settleDuration = Duration(milliseconds: 200);
