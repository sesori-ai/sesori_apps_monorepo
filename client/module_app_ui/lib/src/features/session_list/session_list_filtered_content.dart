import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/list_search_field.dart";
import "session_list_action_dispatcher.dart";
import "session_list_content.dart";
import "session_tile.dart";

/// The active session list under its All / Running / Unread chips, as one
/// sliver. The chosen chip lives here, so every surface filters the same way.
///
/// Where [searchable], a search field above the chips narrows both the list
/// and its counts to matching titles.
///
/// A session inside the shell's archive Undo window is hidden at once, and a
/// committed archive refreshes the list.
///
/// The project's launches lead the active list as launching rows. This is
/// the one place the list resolves which sessions launches hold back, so the
/// rows and the chips' counts agree.
class const SessionListFilteredContent({
  super.key,
  required final String? projectName,
  required final String? selectedSessionId,
  required final SessionOpenedCallback? onSessionTap,
  required final SessionListActionDispatcher actionDispatcher,
  required final Widget archivedEmptyState,
  required final bool searchable,

  /// Told whether the list has launching rows, drawn or kept while it loads,
  /// each time that changes, for a page that would otherwise replace an empty
  /// list.
  required final ValueChanged<bool>? onShowsLaunchRowsChanged,
}) extends StatefulWidget {
  @override
  State<SessionListFilteredContent> createState() => _SessionListFilteredContentState();
}

class _SessionListFilteredContentState() extends State<SessionListFilteredContent> {
  SessionListQuickFilter _filter = SessionListQuickFilter.all;
  String _query = "";
  late final StreamSubscription<PendingSessionArchiveOutcome> _archiveOutcomes;
  late final StreamSubscription<SessionListState> _sessionStates;
  late final StreamSubscription<SessionLaunchState> _launchStates;
  LaunchRows _launchRows = LaunchRows.none;

  @override
  void initState() {
    super.initState();
    _launchRows = _resolveLaunchRows();
    if (_launchRows.placeholders.isNotEmpty) {
      // Not during the build that mounts this list.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onShowsLaunchRowsChanged?.call(_launchRows.placeholders.isNotEmpty);
      });
    }
    final sessions = context.read<SessionListCubit>();
    _sessionStates = sessions.stream.listen((_) => _updateLaunchRows());
    _launchStates = context.read<SessionLaunchCubit>().stream.listen((_) => _updateLaunchRows());
    // The bridge publishes no session event on archive, so a committed archive
    // refreshes the list for the Archived view to show the session at once.
    _archiveOutcomes = context.read<PendingSessionArchiveCubit>().outcomes.listen((outcome) {
      if (outcome case PendingSessionArchiveCommitted() || PendingSessionArchiveWorktreeKept()
          when outcome.session.projectID == sessions.projectId) {
        unawaited(sessions.refreshSessions());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_archiveOutcomes.cancel());
    unawaited(_sessionStates.cancel());
    unawaited(_launchStates.cancel());
    super.dispose();
  }

  void _updateLaunchRows() {
    final showedRows = _launchRows.placeholders.isNotEmpty;
    setState(() => _launchRows = _resolveLaunchRows());
    final showsRows = _launchRows.placeholders.isNotEmpty;
    if (showsRows != showedRows) widget.onShowsLaunchRowsChanged?.call(showsRows);
  }

  /// Run on every list and launch update rather than in build, so each
  /// update is seen once and a launch's session is never missed.
  LaunchRows _resolveLaunchRows() {
    final sessions = context.read<SessionListCubit>();
    final state = sessions.state;
    final launches = context.read<SessionLaunchCubit>().state;
    final launching = [
      for (final launch in launches.launching)
        if (launch.projectId == sessions.projectId) launch,
    ];
    // Archived and loading keep what the active list last showed, so a session
    // that arrives meanwhile is still held on the way back, and still record
    // which session each launch created.
    if (state is! SessionListLoaded || state.filter != SessionListFilter.active) {
      return latchLaunchSessions(previous: _launchRows, launching: launching, sessionIds: launches.sessionIds);
    }
    return resolveHeldLaunchSessions(
      previous: _launchRows,
      launching: launching,
      sessionIds: launches.sessionIds,
      sessions: state.sessions,
      slot: state.sessions,
      placedSessionIds: const {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionListCubit>().state;
    final loaded = state is SessionListLoaded ? state : null;
    final showArchived = loaded != null && loaded.filter != SessionListFilter.active;
    // The chips narrow the active list only; Archived shows everything it has.
    final filter = showArchived ? SessionListQuickFilter.all : _filter;
    // Only the active list draws launching rows and holds their sessions.
    final launchRows = loaded?.filter == SessionListFilter.active ? _launchRows : LaunchRows.none;
    final hidden = {
      ...context.select((PendingSessionArchiveCubit cubit) => cubit.state.hiddenIds),
      ...launchRows.heldSessionIds,
    };
    // The same rule the list applies: only a still-unarchived session hides,
    // so a session being archived leaves the list and the counts at once.
    final counted = matchTitles(
      items: loaded?.sessions ?? const <Session>[],
      titleOf: (session) => session.title,
      query: _query,
    ).where((session) => session.time?.archived != null || !hidden.contains(session.id)).toList();
    final counts = {
      SessionListQuickFilter.all: counted.length,
      SessionListQuickFilter.running: counted
          .where((session) => loaded?.isSessionRunning(session: session) ?? false)
          .length,
      SessionListQuickFilter.unread: counted
          .where((session) => loaded?.isSessionUnseen(session: session) ?? false)
          .length,
    };
    final hasSessions = loaded != null && loaded.sessions.isNotEmpty;
    // A launching row counts, so the search field and chips are already in
    // place when the project's first session takes its row.
    final hasRows = hasSessions || launchRows.placeholders.isNotEmpty;
    final searching = _query.trim().isNotEmpty;

    return SliverMainAxisGroup(
      slivers: [
        if (widget.searchable && hasRows)
          SliverToBoxAdapter(
            child: ListSearchField(
              query: _query,
              hintText: loc.sessionListSearchHint,
              autofocus: false,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              onChanged: (query) => setState(() => _query = query),
            ),
          ),
        if (hasRows && !showArchived)
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
                        key: Key("session-list-filter-${value.name}"),
                        label: switch (value) {
                          SessionListQuickFilter.all => loc.sessionListFilterAll(count),
                          SessionListQuickFilter.running => loc.sessionListFilterRunning(count),
                          SessionListQuickFilter.unread => loc.sessionListFilterUnread(count),
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
          projectName: widget.projectName,
          selectedSessionId: widget.selectedSessionId,
          quickFilter: filter,
          query: _query,
          hiddenSessionIds: hidden,
          launchRows: launchRows,
          onSessionTap: widget.onSessionTap,
          actionDispatcher: widget.actionDispatcher,
          archivedEmptyState: widget.archivedEmptyState,
        ),
        // Unsearched, All can only be empty while its last session is being archived.
        if ((searching || filter != SessionListQuickFilter.all) && counts[filter] == 0 && hasRows)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(PregoSpacing.x3l),
              child: Text(
                searching ? loc.listSearchNoMatches : loc.sessionListFilterEmpty,
                textAlign: TextAlign.center,
                style: context.prego.textTheme.textSm.regular.copyWith(
                  color: context.prego.colors.textTertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
