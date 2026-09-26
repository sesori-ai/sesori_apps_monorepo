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
class const SessionListFilteredContent({
  super.key,
  required final String? projectName,
  required final String? selectedSessionId,
  required final SessionOpenedCallback? onSessionTap,
  required final SessionListActionDispatcher actionDispatcher,
  required final Widget archivedEmptyState,
  required final bool searchable,
}) extends StatefulWidget {
  @override
  State<SessionListFilteredContent> createState() => _SessionListFilteredContentState();
}

class _SessionListFilteredContentState() extends State<SessionListFilteredContent> {
  SessionListQuickFilter _filter = SessionListQuickFilter.all;
  String _query = "";
  late final StreamSubscription<PendingSessionArchiveOutcome> _archiveOutcomes;

  @override
  void initState() {
    super.initState();
    // The bridge publishes no session event on archive, so a committed archive
    // refreshes the list for the Archived view to show the session at once.
    final sessions = context.read<SessionListCubit>();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionListCubit>().state;
    final loaded = state is SessionListLoaded ? state : null;
    final showArchived = loaded != null && loaded.filter != SessionListFilter.active;
    // The chips narrow the active list only; Archived shows everything it has.
    final filter = showArchived ? SessionListQuickFilter.all : _filter;
    final hidden = context.select((PendingSessionArchiveCubit cubit) => cubit.state.hiddenIds);
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
    final searching = _query.trim().isNotEmpty;

    return SliverMainAxisGroup(
      slivers: [
        if (widget.searchable && hasSessions)
          SliverToBoxAdapter(
            child: ListSearchField(
              query: _query,
              hintText: loc.sessionListSearchHint,
              onChanged: (query) => setState(() => _query = query),
            ),
          ),
        if (hasSessions && !showArchived)
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
          onSessionTap: widget.onSessionTap,
          actionDispatcher: widget.actionDispatcher,
          archivedEmptyState: widget.archivedEmptyState,
        ),
        // Unsearched, All can only be empty while its last session is being archived.
        if ((searching || filter != SessionListQuickFilter.all) && counts[filter] == 0 && hasSessions)
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
