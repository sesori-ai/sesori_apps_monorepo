import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";
import "../../widgets/remote_failure_view.dart";
import "session_date_label.dart";
import "session_empty_state.dart";
import "session_list_action_dispatcher.dart";
import "session_list_headings.dart";
import "session_tile.dart";

/// One item of the list: a session, or a launch leading Today.
sealed class const _SessionListItem();

final class const _SessionRow({required final Session session}) extends _SessionListItem;

final class const _LaunchRow({required final LaunchingSession launch}) extends _SessionListItem;

List<SessionListEntry<_SessionListItem>> _sessionListRows({
  required List<LaunchingSession> launches,
  required List<Session> sessions,
  required SessionListLoaded loaded,
  required DateTime now,
  required AppLocalizations loc,
}) => groupUnderHeadings<_SessionListItem>(
  items: [
    // A launch is the newest running thing, so it leads Today, where its
    // session will run.
    for (final launch in launches) _LaunchRow(launch: launch),
    for (final session in sessions) _SessionRow(session: session),
  ],
  headingOf: (item) => switch (item) {
    _LaunchRow() => sessionDateLabel(date: now, now: now, loc: loc),
    // Even with archived rows shown, the list sorts by the last update.
    _SessionRow(:final session) => sessionListHeading(
      timestamp: session.time?.updated,
      isRunning: loaded.isSessionRunning(session: session),
      now: now,
      loc: loc,
    ),
  },
);

/// Pull-to-refresh handler shared by every per-project session list: re-fetches
/// the list, imports from every harness, and reports the reload's outcome via a
/// popup alert. Each host owns its own scroll view and refresh control, so the
/// refresh action lives here, next to the content.
Future<void> refreshSessionList(BuildContext context) async {
  final loc = context.loc;
  final cubit = context.read<SessionListCubit>();
  final success = await cubit.refreshAndImport();
  if (!context.mounted) return;

  PregoPopupAlertPresenter.of(context).show(
    title: success ? loc.sessionListRefreshSuccess : loc.sessionListRefreshFailed,
    variant: success ? PregoPopupAlertsNotificationsVariant.success : PregoPopupAlertsNotificationsVariant.error,
  );
}

class const SessionListContent({
  super.key,
  required final String? projectName,
  final String? selectedSessionId,
  required final SessionListQuickFilter quickFilter,

  /// Narrows the list to titles holding every word; blank shows all.
  required final String query,

  /// Sessions being archived elsewhere, hidden while they still read as
  /// unarchived, and sessions held back while launches settle. Empty where
  /// archive is confirmed in a sheet.
  required final Set<String> hiddenSessionIds,

  /// The launching rows to lead Today with, and the row keys their sessions
  /// took over. Hidden while a quick filter narrows the list or a query is
  /// typed.
  required final LaunchRows launchRows,
  required final SessionOpenedCallback? onSessionTap,
  required final SessionListActionDispatcher actionDispatcher,
  required final Widget archivedEmptyState,
}) extends StatelessWidget {
  /// Returns the page content as a single sliver per state, so it slots
  /// directly into [PregoGlassScaffold]'s scroll view. Pull-to-refresh and the
  /// `isRefreshing` progress bar are owned by [SessionListScaffold]; this only
  /// renders the list/empty/error content.
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionListCubit>().state;
    final onSessionTap = this.onSessionTap;
    final now = DateTime.now();
    final sessions = state is! SessionListLoaded
        ? const <Session>[]
        : matchTitles(items: state.sessions, titleOf: (session) => session.title, query: query)
              .where((session) => session.time?.archived != null || !hiddenSessionIds.contains(session.id))
              .where(
                (session) => switch (quickFilter) {
                  SessionListQuickFilter.all => true,
                  SessionListQuickFilter.running => state.isSessionRunning(session: session),
                  SessionListQuickFilter.unread => state.isSessionUnseen(session: session),
                },
              )
              .toList();
    final launches = quickFilter == SessionListQuickFilter.all && query.trim().isEmpty
        ? launchRows.placeholders
        : const <LaunchingSession>[];
    final rows = state is! SessionListLoaded
        ? const <SessionListEntry<_SessionListItem>>[]
        : _sessionListRows(launches: launches, sessions: sessions, loaded: state, now: now, loc: loc);

    return switch (state) {
      SessionListLoading() => SliverToBoxAdapter(
        child: PregoSkeletonList(semanticLabel: loc.sessionListLoadingSemantics),
      ),
      final SessionListLoaded loaded => SliverMainAxisGroup(
        slivers: [
          // This sliver stays mounted when the list becomes empty, giving the
          // final removed row time to close before the empty state settles in.
          PregoAnimatedSliverList<SessionListEntry<_SessionListItem>>(
            items: rows,
            itemKey: (row) => switch (row) {
              final SessionListHeadingEntry<_SessionListItem> heading => heading.key,
              SessionListItemEntry(item: _SessionRow(:final session)) => ValueKey(
                launchRows.rowKeys[session.id] ?? session.id,
              ),
              SessionListItemEntry(item: _LaunchRow(:final launch)) => ValueKey(launch.launchId),
            },
            itemBuilder: (_, index, row) {
              switch (row) {
                case SessionListHeadingEntry(:final heading):
                  return SessionListHeading(heading: heading, isFirst: index == 0);
                case SessionListItemEntry(item: _LaunchRow(:final launch)):
                  return _settling(
                    context: context,
                    launching: true,
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(bottom: index == rows.length - 1 ? 8 : 0),
                      child: PendingSessionLaunchTile(launch: launch),
                    ),
                  );
                case SessionListItemEntry(item: _SessionRow(:final session)):
                  final activityInfo = loaded.activeSessionIds[session.id];
                  final row = Padding(
                    // Keep the list's bottom breathing room attached to its last
                    // row so that space collapses with the final item.
                    padding: EdgeInsetsDirectional.only(bottom: index == rows.length - 1 ? 8 : 0),
                    child: SessionTile(
                      session: session,
                      // The list is one project's, so its rows don't repeat it.
                      projectLabel: null,
                      isArchived: session.time?.archived != null,
                      isRunning: loaded.isSessionRunning(session: session),
                      unseen: loaded.isSessionUnseen(session: session),
                      selected: selectedSessionId == session.id,
                      awaitingInput: activityInfo?.awaitingInput ?? false,
                      isRetrying: activityInfo?.isRetrying ?? false,
                      backgroundTaskCount: activityInfo?.backgroundTaskCount ?? 0,
                      onTap: onSessionTap == null ? null : () => onSessionTap(session: session),
                      // The list's context, not the row's: archive/delete
                      // unmount the row before their follow-ups run.
                      menuEntries: () => actionDispatcher.sessionMenuEntries(
                        context: context,
                        cubit: context.read<SessionListCubit>(),
                        session: session,
                        readEntry: SessionReadMenuEntry.toggle,
                      ),
                      onArchive: () => actionDispatcher.handleSessionArchive(
                        context: context,
                        cubit: context.read<SessionListCubit>(),
                        session: session,
                      ),
                      onDelete: () => actionDispatcher.handleSessionDelete(
                        context: context,
                        cubit: context.read<SessionListCubit>(),
                        session: session,
                      ),
                      onToggleUnread: () => actionDispatcher.handleSessionToggleUnread(
                        context: context,
                        cubit: context.read<SessionListCubit>(),
                        session: session,
                      ),
                    ),
                  );
                  return launchRows.rowKeys.containsKey(session.id)
                      ? _settling(context: context, launching: false, child: row)
                      : row;
              }
            },
          ),
          if (loaded.sessions.isEmpty && launchRows.placeholders.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: (loaded.filter != SessionListFilter.active)
                  ? archivedEmptyState
                  : SessionEmptyState(projectName: projectName),
            ),
        ],
      ),
      SessionListFailed(:final reason) => SliverFillRemaining(
        hasScrollBody: false,
        child: RemoteFailureView(
          reason: reason,
          title: context.loc.sessionListErrorTitle,
          retryLabel: context.loc.sessionListRetry,
          onRetry: () => context.read<SessionListCubit>().retryLoadSessions(),
        ),
      ),
    };
  }

  /// A launching row and the session row that takes its place share one
  /// list item, so the change cross-fades in place rather than collapsing one
  /// row and opening another.
  static Widget _settling({required BuildContext context, required bool launching, required Widget child}) =>
      AnimatedSwitcher(
        duration: prefersReducedMotion(context) ? Duration.zero : _settleDuration,
        child: KeyedSubtree(key: ValueKey(launching), child: child),
      );
}

const Duration _settleDuration = Duration(milliseconds: 200);
