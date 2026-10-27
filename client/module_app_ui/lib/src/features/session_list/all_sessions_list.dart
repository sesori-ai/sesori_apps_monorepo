import "dart:async";
import "dart:math" as math;

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

/// The page, as a sliver, for a computer that is not connected, or null while
/// the surface knows it is about to connect: the list then shows its own
/// loading, which hands off to the rows like any load.
typedef AllSessionsDisconnectedBuilder = Widget? Function({
  required BuildContext context,
  required ProjectListBridgeDisconnected state,
});

/// The [AllSessionsCubit] list across projects, as one sliver: its rows under
/// date headings, in the cubit's order. Each row names its project unless the
/// list is filtered to one (D3).
///
/// The project list comes first: while it cannot load, or the computer is not
/// connected, the list shows that in place of its rows, unless the surface
/// calls the disconnection a load.
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
    final ProjectListBridgeDisconnected disconnected =>
      disconnectedBuilder(context: context, state: disconnected) ??
          _sessions(context: context, awaitingConnection: true),
    ProjectListLoading() || ProjectListLoaded() => _sessions(context: context, awaitingConnection: false),
  };

  /// The same subtree whether it waits on the computer or on its projects, so
  /// one loading skeleton stays from the one to the other.
  Widget _sessions({required BuildContext context, required bool awaitingConnection}) =>
      switch (context.read<AllSessionsCubit>().mode) {
        AllSessionsMode.active => _ActiveSessions(list: this, awaitingConnection: awaitingConnection),
        AllSessionsMode.archived => _Sessions(
          list: this,
          awaitingConnection: awaitingConnection,
          launchRows: const {},
          hiddenSessionIds: const {},
        ),
      };
}

class const _ActiveSessions({
  required final AllSessionsList list,
  required final bool awaitingConnection,
}) extends StatefulWidget {
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
      return _Sessions(
        list: widget.list,
        awaitingConnection: widget.awaitingConnection,
        launchRows: launchRows,
        hiddenSessionIds: hidden,
      );
    },
  );
}

/// One item of the list: a session, or a launch leading Today.
sealed class const _Item();

final class const _SessionItem({required final AllSessionsRow row}) extends _Item;

final class const _LaunchItem({required final LaunchingSession launch}) extends _Item;

class const _Sessions({
  required final AllSessionsList list,

  /// Whether the list waits on a computer about to connect: a load, though
  /// nothing loads yet.
  required final bool awaitingConnection,
  required final Map<String, LaunchRows> launchRows,
  required final Set<String> hiddenSessionIds,
}) extends StatefulWidget {
  @override
  State<_Sessions> createState() => _SessionsState();
}

class _SessionsState() extends State<_Sessions> with SingleTickerProviderStateMixin {
  /// The hand-off from the loading skeleton to the first rows or the empty
  /// state: they fade in where the skeleton stood while it fades itself out
  /// over them, and the room no sessions take folds away. It runs backwards
  /// as a load replaces what the list shows, such as a computer switch's: it
  /// stays, fading out, as the skeleton fades in over it from where it will
  /// stand and the folded room opens. Complete at rest, so later updates show
  /// as they always do.
  late final AnimationController _handOff = AnimationController(
    vsync: this,
    duration: transcriptMotionDuration,
    value: 1,
  );
  late final CurvedAnimation _contentOpacity = CurvedAnimation(parent: _handOff, curve: transcriptMotionCurve);
  late final Animation<double> _skeletonArrival = ReverseAnimation(_contentOpacity);

  /// Keeps the one skeleton, with its appearance delay and sheen, as it moves
  /// from its own place onto the content that replaces it.
  final GlobalKey _skeletonKey = GlobalKey(debugLabel: "all-sessions-skeleton");
  bool _wasLoading = false;

  /// Counts the content's fades in, so the rows of each start as a list of
  /// their own instead of moving in among the rows a load replaced.
  int _contentFades = 0;

  /// What the list last showed when not loading, kept through a load that
  /// replaces it.
  AllSessionsState? _lastShown;

  /// Whether what a load replaces still shows, fading out.
  bool get _replacing => _handOff.status == AnimationStatus.reverse;

  /// A skeleton waits before it shows, so a fast load never flashes it, but
  /// not over what it replaces, which leaves nothing blank to hide.
  Duration get _skeletonAppearDelay => _lastShown == null ? PregoShimmer.defaultAppearDelay : Duration.zero;

  /// The failed project listed last above the loading skeleton: it leaves
  /// from under that row while the row is still listed.
  String? _skeletonUnderFailureId;

  @override
  void initState() {
    super.initState();
    _handOff.addStatusListener((status) {
      // The faded skeleton leaves the tree.
      if (status.isCompleted) setState(() {});
    });
  }

  /// Fades the content in where the skeleton stands, timed from the next
  /// frame: this one mounts the content and can be slow enough to use up the
  /// whole fade.
  void _fadeContentIn() {
    _contentFades++;
    _handOff.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handOff.forward();
    });
  }

  @override
  void dispose() {
    _contentOpacity.dispose();
    _handOff.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _Sessions(:list, :awaitingConnection, :launchRows, :hiddenSessionIds) = widget;
    final loc = context.loc;
    final prego = context.prego;
    final cubit = context.read<AllSessionsCubit>();
    final current = context.watch<AllSessionsCubit>().state;
    final now = DateTime.now();
    // The list's bottom breathing room collapses with its last row, which
    // rests above the home indicator and anything floating there.
    final endPadding = 8 + MediaQuery.paddingOf(context).bottom + list.endClearance;
    // A launching row has no title to match, and is neither running nor
    // unread yet, so a search or a chip hides it.
    List<LaunchingSession> launchesOf(AllSessionsState state) =>
        state.query.trim().isNotEmpty || state.quickFilter != SessionListQuickFilter.all
        ? const <LaunchingSession>[]
        : [
            for (final MapEntry(key: projectId, value: rows) in launchRows.entries)
              if (state.projectId == null || state.projectId == projectId) ...rows.placeholders,
          ];
    List<SessionListEntry<_Item>> entriesOf(AllSessionsState state) => groupUnderHeadings<_Item>(
      items: [
        for (final launch in launchesOf(state)) _LaunchItem(launch: launch),
        // Only a still-unarchived session hides, as on every list.
        for (final row in state.rows)
          if (row.session.time?.archived != null || !hiddenSessionIds.contains(row.session.id)) _SessionItem(row: row),
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
    final currentEntries = entriesOf(current);
    final currentlyLoading = (awaitingConnection || current.isLoading) && currentEntries.isEmpty;
    if (_wasLoading && !currentlyLoading && !context.isReducedMotion) {
      // Rows still fading out finish first, so the content follows the
      // skeleton they leave.
      if (!_replacing) _fadeContentIn();
    } else if (!_wasLoading && currentlyLoading && _lastShown != null && !context.isReducedMotion) {
      // The rows glide to the top as they fade, where the skeleton they
      // leave stands with nothing to scroll.
      final position = Scrollable.maybeOf(context)?.position;
      if (position != null && position.pixels > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(position.animateTo(0, duration: transcriptMotionDuration, curve: transcriptMotionCurve));
          }
        });
      }
      unawaited(
        _handOff.reverse().then((_) {
          if (!mounted) return;
          // Back at rest as the load goes on, or on to the content that
          // ended it while the rows faded out.
          if (_wasLoading) {
            _handOff.value = 1;
          } else {
            setState(_fadeContentIn);
          }
        }),
      );
    }
    _wasLoading = currentlyLoading;
    if (currentlyLoading) _skeletonUnderFailureId = current.failures.lastOrNull?.project.id;
    final state = (_replacing ? _lastShown : null) ?? current;
    final entries = identical(state, current) ? currentEntries : entriesOf(state);
    if (!currentlyLoading && !_replacing) _lastShown = current;
    final searching = state.query.trim().isNotEmpty;
    // A launching row counts, so the search field and chips are already in
    // place when a first session takes its row.
    final hasSessions = state.counts.all > 0 || launchesOf(state).isNotEmpty || searching;
    final isLoading = awaitingConnection || state.isLoading;
    final loading = isLoading && entries.isEmpty;
    final isActive = cubit.mode == AllSessionsMode.active;
    // The skeleton fades out where it stood, or in where it will stand:
    // hanging from the failed project it stands under, else from the room
    // above the failed projects. At most one place holds it.
    final handingOff = !loading && !_handOff.isCompleted;
    final heldUnderFailures =
        handingOff && state.failures.any((failure) => failure.project.id == _skeletonUnderFailureId);
    final heldAboveFailures = handingOff && !heldUnderFailures;
    // The search field shows from a load's first frame, so nothing under it
    // moves when the rows arrive. A load that ends with nothing to search
    // folds it and the chips' room away as the empty state fades in.
    final searchShown = hasSessions || loading || handingOff;
    final roomFolds = handingOff && !hasSessions;
    // The chips show counts, so until the load has some, a skeleton pill
    // holds each chip's place. Through the hand-off it fades out where it
    // stands as the chip fades in over it, one that never showed staying
    // hidden.
    final chipsShown = loading ? state.counts.all > 0 : hasSessions;
    final chipsHeld = (loading && state.counts.all == 0) || handingOff;
    Widget folding({required Widget child}) => ListenableBuilder(
      listenable: _contentOpacity,
      // The fade's ease-out, run backwards: an ease-in fold, as a transcript row's.
      builder: (_, child) {
        final size = roomFolds ? 1 - _contentOpacity.value : 1.0;
        return _sized(
          size: size,
          child: Opacity(opacity: size, child: child),
        );
      },
      child: child,
    );
    final searchField = ListSearchField(
      query: state.query,
      hintText: loc.sessionListSearchHint,
      autofocus: false,
      padding: EdgeInsets.zero,
      onChanged: (query) => cubit.setQuery(query: query),
    );
    Widget chip({required SessionListQuickFilter filter, required Key? key, required SessionListChipCounts counts}) =>
        Semantics(
          toggled: state.quickFilter == filter,
          child: PregoButtonsSolid(
            key: key,
            label: switch (filter) {
              SessionListQuickFilter.all => loc.sessionListFilterAll(counts.all),
              SessionListQuickFilter.running => loc.sessionListFilterRunning(counts.running),
              SessionListQuickFilter.unread => loc.sessionListFilterUnread(counts.unread),
            },
            hierarchy: state.quickFilter == filter
                ? PregoButtonsSolidHierarchy.primaryAlt
                : PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.sm,
            onPressed: () => cubit.setQuickFilter(filter: filter),
          ),
        );
    Widget chips({required Widget Function(SessionListQuickFilter filter) each}) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
      child: Wrap(
        spacing: PregoSpacing.md,
        runSpacing: PregoSpacing.md,
        children: [for (final filter in SessionListQuickFilter.values) each(filter)],
      ),
    );
    final settled = !isLoading && state.failures.isEmpty && entries.isEmpty;
    final note = switch (settled) {
      false => null,
      true when searching => loc.listSearchNoMatches,
      // Unsearched, All can only be empty while its last session hides.
      true when state.counts.all > 0 && state.quickFilter != SessionListQuickFilter.all => loc.sessionListFilterEmpty,
      true => null,
    };

    return SliverMainAxisGroup(
      slivers: [
        // Keyed, so the header keeps its state as the boxes around it come and go.
        if (searchShown)
          SliverToBoxAdapter(
            key: const ValueKey("all-sessions-search"),
            child: _holding(
              // The archived list's last box above the failed projects: only
              // the active list has a header.
              skeleton: heldAboveFailures && !isActive,
              child: folding(
                child: Padding(padding: _searchFieldPadding, child: searchField),
              ),
            ),
          ),
        if (list.header case final header?)
          SliverToBoxAdapter(key: const ValueKey("all-sessions-header"), child: header),
        if (isActive && (chipsShown || chipsHeld))
          SliverToBoxAdapter(
            key: const ValueKey("all-sessions-chips"),
            child: _holding(
              // The active list's last box above the failed projects.
              skeleton: heldAboveFailures,
              child: folding(
                // The arriving counts can wrap the chips onto another line;
                // the room eases to it rather than snapping what is below.
                child: _easedSize(
                  context: context,
                  child: SizedBox(
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.passthrough,
                      children: [
                        if (chipsShown)
                          FadeTransition(
                            key: const ValueKey("content"),
                            opacity: _contentOpacity,
                            child: IgnorePointer(
                              ignoring: _replacing,
                              child: chips(
                                each: (filter) => chip(
                                  filter: filter,
                                  key: Key("session-list-filter-${filter.name}"),
                                  counts: state.counts,
                                ),
                              ),
                            ),
                          ),
                        // Held at the loading counts, so the pills fade out
                        // where they stood, or in with the list's skeleton.
                        if (chipsHeld)
                          IgnorePointer(
                            key: const ValueKey("skeleton"),
                            child: FadeTransition(
                              opacity: _replacing ? _skeletonArrival : kAlwaysCompleteAnimation,
                              child: PregoShimmer(
                                leaving: !loading && !_replacing,
                                appearDelay: _skeletonAppearDelay,
                                child: chips(
                                  each: (filter) => _barOver(
                                    shape: chip(filter: filter, key: null, counts: _noCounts),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        for (final failure in state.failures)
          SliverToBoxAdapter(
            key: ValueKey("all-sessions-failure-${failure.project.id}"),
            child: _holding(
              skeleton: heldUnderFailures && failure.project.id == _skeletonUnderFailureId,
              // Shown as soon as the project fails. Read once, when it first
              // builds: one failing while the skeleton shows opens over it,
              // easing it down, while one arriving with the hand-off only
              // fades in alongside the first rows, so nothing moves under them.
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: loading ? 0 : 1, end: 1),
                duration: context.isReducedMotion ? Duration.zero : transcriptMotionDuration,
                curve: transcriptMotionCurve,
                builder: (_, size, child) => _sized(size: size, child: child),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: context.isReducedMotion ? Duration.zero : transcriptMotionDuration,
                  curve: transcriptMotionCurve,
                  builder: (_, opacity, child) => Opacity(
                    opacity: opacity,
                    // It fades out with the rows a load replaces.
                    child: IgnorePointer(
                      ignoring: _replacing,
                      child: FadeTransition(
                        opacity: _replacing ? _contentOpacity : kAlwaysCompleteAnimation,
                        child: child,
                      ),
                    ),
                  ),
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
              ),
            ),
          ),
        if (loading)
          // Only the room left in the viewport, cut off at its bottom edge, so
          // a loading list has nothing to scroll and its scroll range does not
          // shrink as the rows arrive.
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverToBoxAdapter(
              child: SizedBox(
                height: math.max(0, constraints.viewportMainAxisExtent - constraints.precedingScrollExtent),
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: double.infinity,
                    child: _skeleton(context: context, leaving: false),
                  ),
                ),
              ),
            ),
          )
        else
          // Mounted with the first rows at full size, which fade in with the
          // hand-off. It stays mounted when the list becomes empty, giving the
          // final removed row time to close before the empty state settles in.
          SliverFadeTransition(
            key: ValueKey(_contentFades),
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
                SessionListItemEntry(item: _LaunchItem(:final launch)) => IgnorePointer(
                  ignoring: _replacing,
                  child: _launchRowSettling(
                    context: context,
                    launching: true,
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(bottom: index == entries.length - 1 ? endPadding : 0),
                      child: PendingSessionLaunchTile(launch: launch),
                    ),
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
            child: FadeTransition(opacity: _contentOpacity, child: list.emptyState),
          ),
      ],
    );
  }

  Widget _skeleton({required BuildContext context, required bool leaving}) => FadeTransition(
    opacity: _replacing ? _skeletonArrival : kAlwaysCompleteAnimation,
    child: SessionListSkeleton(key: _skeletonKey, leaving: leaving, appearDelay: _skeletonAppearDelay),
  );

  /// [child], with the skeleton, if it holds the [skeleton], fading out over
  /// what follows, or in over the rows a load replaces, hanging from its
  /// bottom without taking room.
  Widget _holding({required bool skeleton, required Widget child}) => Stack(
    fit: StackFit.passthrough,
    clipBehavior: Clip.none,
    children: [
      child,
      if (skeleton)
        PositionedDirectional(
          bottom: 0,
          start: 0,
          end: 0,
          height: 0,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            maxHeight: double.infinity,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: _skeleton(context: context, leaving: !_replacing),
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
    // A row a load replaces fades out without taking taps.
    return IgnorePointer(
      ignoring: _replacing,
      child: tookLaunchRow ? _launchRowSettling(context: context, launching: false, child: tile) : tile,
    );
  }
}

const EdgeInsetsGeometry _searchFieldPadding = EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0);

/// [child] at [size] of its height, folded from its bottom: the same widgets
/// at rest and in motion, so it keeps its state, and clipped only while it
/// moves.
Widget _sized({required double size, required Widget? child}) => ClipRect(
  clipBehavior: size < 1 ? Clip.hardEdge : Clip.none,
  child: Align(alignment: AlignmentDirectional.topStart, heightFactor: size, child: child),
);

/// The session list's loading placeholder, shaped like the grouped list it
/// stands for: a date heading over a few rows, in groups of 3, 2 and 4 rows
/// repeated until the screen's height is covered, for the list to cut off at
/// its viewport's bottom edge. The pattern is fixed, so the groups never
/// reshuffle as it rebuilds.
class const SessionListSkeleton({
  super.key,
  required final bool leaving,

  /// See [PregoShimmer.appearDelay].
  required final Duration appearDelay,
}) extends StatelessWidget {
  static const List<int> _groupSizes = [3, 2, 4];

  /// Close to the widths of "Today", "Yesterday" and a weekday.
  static const List<double> _headingWidths = [40, 64, 56];
  static const List<double> _titleWidths = [0.72, 0.5, 0.84, 0.6, 0.44, 0.78, 0.56, 0.66, 0.48];

  /// Close to the widths of project names.
  static const List<double> _detailsWidths = [88, 64, 76];

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final rowHeight = SessionTileSkeleton.heightOf(
      pointer: PregoInteractionScope.of(context) == PregoInteractionMode.pointer,
    );
    final children = <Widget>[];
    var height = 0.0;
    var row = 0;
    for (var group = 0; height < screenHeight; group++) {
      final isFirst = group == 0;
      children.add(SessionListHeadingSkeleton(isFirst: isFirst, width: _headingWidths[group % _headingWidths.length]));
      height += SessionListHeadingSkeleton.heightOf(isFirst: isFirst);
      for (var index = 0; index < _groupSizes[group % _groupSizes.length]; index++, row++) {
        children.add(
          SessionTileSkeleton(
            titleWidthFraction: _titleWidths[row % _titleWidths.length],
            detailsWidth: _detailsWidths[row % _detailsWidths.length],
          ),
        );
        height += rowHeight;
      }
    }
    return PregoShimmer(
      semanticLabel: context.loc.sessionListLoadingSemantics,
      leaving: leaving,
      appearDelay: appearDelay,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// A load holds the chips' placeholders only while it has no counts.
const _noCounts = SessionListChipCounts(all: 0, running: 0, unread: 0);

/// [child], easing between its heights; at once with reduced motion, where a
/// zero-length [AnimatedSize] would re-dirty itself mid-layout.
Widget _easedSize({required BuildContext context, required Widget child}) => context.isReducedMotion
    ? child
    : AnimatedSize(
        duration: transcriptMotionDuration,
        curve: transcriptMotionCurve,
        alignment: AlignmentDirectional.topStart,
        clipBehavior: Clip.none,
        child: child,
      );

/// [shape] laid out unseen, holding its room under a skeleton bar of its
/// size.
Widget _barOver({required Widget shape}) => Stack(
  fit: StackFit.passthrough,
  children: [
    Visibility(visible: false, maintainState: true, maintainAnimation: true, maintainSize: true, child: shape),
    const Positioned.fill(child: PregoSkeletonBar(height: double.infinity)),
  ],
);

/// A launching row and the session row that takes its place share one list
/// item, so the change cross-fades in place rather than collapsing one row and
/// opening another.
Widget _launchRowSettling({required BuildContext context, required bool launching, required Widget child}) =>
    AnimatedSwitcher(
      duration: prefersReducedMotion(context) ? Duration.zero : _settleDuration,
      child: KeyedSubtree(key: ValueKey(launching), child: child),
    );

const Duration _settleDuration = Duration(milliseconds: 200);
