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
import "session_tile.dart";

/// A widget-local narrowing of the active list. The list is fully loaded, so
/// this filters what is shown and never asks the cubit for anything.
enum SessionListQuickFilter() {
  all,
  running,
  unread,
}

/// Chooses one stable heading for a session without changing the service-owned
/// ordering of [SessionListLoaded.sessions]. The loaded-state resolver supplies
/// running classification; presentation only chooses the localized heading.
String _sessionListHeading({
  required Session session,
  required SessionListFilter filter,
  required bool isRunning,
  required DateTime now,
  required AppLocalizations loc,
}) {
  final isArchivedList = filter == SessionListFilter.archived;
  // One timeline: a running session is a row of Today, whatever its stored
  // time, and the row itself says it is running.
  if (!isArchivedList && isRunning) return sessionDateLabel(date: now, now: now, loc: loc);

  final timestamp = isArchivedList ? session.time?.archived : session.time?.updated;
  return sessionDateLabel(
    date: timestamp == null ? null : DateTime.fromMillisecondsSinceEpoch(timestamp),
    now: now,
    loc: loc,
  );
}

/// One entry of the animated list: a date heading or a session under it.
///
/// Headings are entries of their own, so archiving the first session of a
/// group animates only that row; the heading leaves only with its last session.
sealed class const _SessionListRow();

final class const _SessionHeadingRow({
  required final String heading,

  /// How many earlier groups share [heading]. Only a running session placed
  /// out of date order repeats a heading, and it must not repeat the key.
  required final int occurrence,
}) extends _SessionListRow;

final class const _SessionRow({required final Session session}) extends _SessionListRow;

final class const _SessionHeadingKey(super.value) extends ValueKey<(String, int)>;

List<_SessionListRow> _sessionListRows({
  required List<Session> sessions,
  required SessionListLoaded loaded,
  required DateTime now,
  required AppLocalizations loc,
}) {
  final rows = <_SessionListRow>[];
  final occurrences = <String, int>{};
  String? previousHeading;
  for (final session in sessions) {
    final heading = _sessionListHeading(
      session: session,
      filter: loaded.filter,
      isRunning: loaded.isSessionRunning(session: session),
      now: now,
      loc: loc,
    );
    if (heading != previousHeading) {
      final occurrence = occurrences.update(heading, (count) => count + 1, ifAbsent: () => 0);
      rows.add(_SessionHeadingRow(heading: heading, occurrence: occurrence));
      previousHeading = heading;
    }
    rows.add(_SessionRow(session: session));
  }
  return rows;
}

/// Pull-to-refresh handler shared by [SessionListScaffold] and
/// [SessionListPanel]: re-fetches the session list and reports the outcome via
/// a popup alert. Both hosts own their own scroll view and refresh control, so the
/// refresh action lives here, next to the content.
Future<void> refreshSessionList(BuildContext context) async {
  final loc = context.loc;
  final cubit = context.read<SessionListCubit>();
  final success = await cubit.refreshSessions(waitForPrData: true);
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
  /// unarchived. Empty where archive is confirmed in a sheet.
  required final Set<String> hiddenSessionIds,
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
    final rows = state is! SessionListLoaded
        ? const <_SessionListRow>[]
        : _sessionListRows(sessions: sessions, loaded: state, now: now, loc: loc);

    return switch (state) {
      SessionListLoading() => SliverToBoxAdapter(
        child: PregoSkeletonList(semanticLabel: loc.sessionListLoadingSemantics),
      ),
      final SessionListLoaded loaded => SliverMainAxisGroup(
        slivers: [
          // This sliver stays mounted when the list becomes empty, giving the
          // final removed row time to close before the empty state settles in.
          PregoAnimatedSliverList<_SessionListRow>(
            items: rows,
            itemKey: (row) => switch (row) {
              _SessionHeadingRow(:final heading, :final occurrence) => _SessionHeadingKey((heading, occurrence)),
              _SessionRow(:final session) => ValueKey(session.id),
            },
            itemBuilder: (_, index, row) {
              switch (row) {
                case _SessionHeadingRow(:final heading):
                  return Padding(
                    // The first heading carries the list's top breathing room, so
                    // archiving the row below it leaves the heading where it is.
                    padding: EdgeInsetsDirectional.fromSTEB(16, 16, 16, index == 0 ? 20 : 12),
                    child: Text(
                      heading,
                      style: context.prego.textTheme.textSm.medium.copyWith(
                        color: context.prego.colors.textTertiary,
                      ),
                    ),
                  );
                case _SessionRow(:final session):
                  final activityInfo = loaded.activeSessionIds[session.id];
                  return Padding(
                    // Keep the list's bottom breathing room attached to its last
                    // row so that space collapses with the final item.
                    padding: EdgeInsetsDirectional.only(bottom: index == rows.length - 1 ? 8 : 0),
                    child: SessionTile(
                      session: session,
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
                      onArchive: () => actionDispatcher.handleSessionArchive(context: context, session: session),
                      onDelete: () => actionDispatcher.handleSessionDelete(context: context, session: session),
                      onToggleUnread: () => actionDispatcher.handleSessionToggleUnread(
                        context: context,
                        session: session,
                      ),
                    ),
                  );
              }
            },
          ),
          if (loaded.sessions.isEmpty)
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
}
