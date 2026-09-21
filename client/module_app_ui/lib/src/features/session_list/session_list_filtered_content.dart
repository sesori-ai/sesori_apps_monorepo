import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "session_list_action_dispatcher.dart";
import "session_list_content.dart";
import "session_tile.dart";

/// The active session list under its All / Running / Unread chips, as one
/// sliver. The chosen chip lives here, so every surface filters the same way.
class const SessionListFilteredContent({
  super.key,
  required final String? projectName,
  required final String? selectedSessionId,

  /// Sessions being archived elsewhere, hidden while they still read as
  /// unarchived. Empty where archive is confirmed in a sheet.
  required final Set<String> hiddenSessionIds,
  required final SessionOpenedCallback? onSessionTap,
  required final SessionListActionDispatcher actionDispatcher,
  required final Widget archivedEmptyState,
}) extends StatefulWidget {
  @override
  State<SessionListFilteredContent> createState() => _SessionListFilteredContentState();
}

class _SessionListFilteredContentState() extends State<SessionListFilteredContent> {
  SessionListQuickFilter _filter = SessionListQuickFilter.all;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionListCubit>().state;
    final loaded = state is SessionListLoaded ? state : null;
    final showArchived = loaded != null && loaded.filter != SessionListFilter.active;
    // The chips narrow the active list only; Archived shows everything it has.
    final filter = showArchived ? SessionListQuickFilter.all : _filter;
    // The same rule the list applies: only a still-unarchived session hides,
    // so a session being archived leaves the list and the counts at once.
    final counted =
        loaded?.sessions
            .where((session) => session.time?.archived != null || !widget.hiddenSessionIds.contains(session.id))
            .toList() ??
        const <Session>[];
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

    return SliverMainAxisGroup(
      slivers: [
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
          hiddenSessionIds: widget.hiddenSessionIds,
          onSessionTap: widget.onSessionTap,
          actionDispatcher: widget.actionDispatcher,
          archivedEmptyState: widget.archivedEmptyState,
        ),
        // All can only be empty while its last session is being archived.
        if (filter != SessionListQuickFilter.all && counts[filter] == 0 && hasSessions)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(PregoSpacing.x3l),
              child: Text(
                loc.sessionListFilterEmpty,
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
