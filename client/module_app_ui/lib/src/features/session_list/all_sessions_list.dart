import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/list_search_field.dart";
import "../project_list/widgets/project_tile.dart";
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

/// The [AllSessionsCubit] list across projects, as one sliver: its rows under
/// date headings, in the cubit's order. Each row names its project unless the
/// list is filtered to one (D3).
///
/// A row's actions run on its own action-mode [SessionListCubit], built only
/// once a swipe or menu needs it.
class const AllSessionsList({
  super.key,
  required final AllSessionsRowOpenedCallback onSessionTap,
  required final SessionListActionDispatcher actionDispatcher,
  required final ActionSessionListCubitFactory createActionCubit,

  /// Shown when nothing loads, fails or matches a query.
  required final Widget emptyState,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final cubit = context.read<AllSessionsCubit>();
    final state = context.watch<AllSessionsCubit>().state;
    final now = DateTime.now();
    final entries = groupUnderHeadings(
      items: state.rows,
      headingOf: (row) => sessionListHeading(session: row.session, isRunning: row.isRunning, now: now, loc: loc),
    );
    final searching = state.query.trim().isNotEmpty;
    final settled = !state.isLoading && state.rows.isEmpty && state.failures.isEmpty;

    return SliverMainAxisGroup(
      slivers: [
        if (state.rows.isNotEmpty || state.query.isNotEmpty)
          SliverToBoxAdapter(
            child: ListSearchField(
              query: state.query,
              hintText: loc.sessionListSearchHint,
              autofocus: false,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              onChanged: (query) => cubit.setQuery(query: query),
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
        if (state.isLoading && state.rows.isEmpty)
          SliverToBoxAdapter(child: PregoSkeletonList(semanticLabel: loc.sessionListLoadingSemantics)),
        // This sliver stays mounted when the list becomes empty, giving the
        // final removed row time to close before the empty state settles in.
        PregoAnimatedSliverList<SessionListEntry<AllSessionsRow>>(
          items: entries,
          itemKey: (entry) => switch (entry) {
            final SessionListHeadingEntry<AllSessionsRow> heading => heading.key,
            SessionListItemEntry(item: final row) => ValueKey((row.project.id, row.session.id)),
          },
          itemBuilder: (_, index, entry) => switch (entry) {
            SessionListHeadingEntry(:final heading) => SessionListHeading(heading: heading, isFirst: index == 0),
            SessionListItemEntry(item: final row) => Padding(
              // The list's bottom breathing room collapses with its last row.
              padding: EdgeInsetsDirectional.only(bottom: index == entries.length - 1 ? 8 : 0),
              child: BlocProvider(
                create: (_) => createActionCubit(projectId: row.project.id, session: row.session),
                child: Builder(
                  builder: (rowContext) {
                    SessionListCubit actions() =>
                        rowContext.read<SessionListCubit>()..updateActionSession(session: row.session);
                    // Actions run against the list's context, not the row's:
                    // a delete unmounts the row before its follow-ups run.
                    return SessionTile(
                      session: row.session,
                      projectLabel: state.projectId == null ? projectDisplayName(loc: loc, project: row.project) : null,
                      isArchived: row.session.time?.archived != null,
                      isRunning: row.isRunning,
                      unseen: row.isUnseen,
                      awaitingInput: row.isAwaitingInput,
                      isRetrying: row.isRetrying,
                      backgroundTaskCount: row.backgroundTaskCount,
                      onTap: () => onSessionTap(row: row),
                      menuEntries: () => actionDispatcher.sessionMenuEntries(
                        context: context,
                        cubit: actions(),
                        session: row.session,
                        readEntry: SessionReadMenuEntry.toggle,
                      ),
                      onArchive: () => actionDispatcher.handleSessionArchive(
                        context: context,
                        cubit: actions(),
                        session: row.session,
                      ),
                      onDelete: () => actionDispatcher.handleSessionDelete(
                        context: context,
                        cubit: actions(),
                        session: row.session,
                      ),
                      onToggleUnread: () => actionDispatcher.handleSessionToggleUnread(
                        context: context,
                        cubit: actions(),
                        session: row.session,
                      ),
                    );
                  },
                ),
              ),
            ),
          },
        ),
        if (settled && searching)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(PregoSpacing.x3l),
              child: Text(
                loc.listSearchNoMatches,
                textAlign: TextAlign.center,
                style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textTertiary),
              ),
            ),
          ),
        if (settled && !searching) SliverFillRemaining(hasScrollBody: false, child: emptyState),
      ],
    );
  }
}
