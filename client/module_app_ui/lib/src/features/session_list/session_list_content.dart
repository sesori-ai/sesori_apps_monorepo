import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/remote_failure_view.dart";
import "session_empty_state.dart";
import "session_list_action_dispatcher.dart";
import "session_tile.dart";

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

    return switch (state) {
      SessionListLoading() => SliverToBoxAdapter(
        child: PregoSkeletonList(semanticLabel: loc.sessionListLoadingSemantics),
      ),
      final SessionListLoaded loaded => SliverMainAxisGroup(
        slivers: [
          // This sliver stays mounted when the list becomes empty, giving the
          // final removed row time to close before the empty state settles in.
          PregoAnimatedSliverList<Session>(
            items: loaded.sessions,
            itemKey: (session) => ValueKey(session.id),
            itemBuilder: (_, index, session) {
              final isArchived = session.time?.archived != null;
              final activityInfo = loaded.activeSessionIds[session.id];

              return Padding(
                // Keep the list's outer breathing room attached to its first
                // and last rows so that space collapses with the final item.
                padding: EdgeInsetsDirectional.only(
                  top: index == 0 ? 8 : 0,
                  bottom: index == loaded.sessions.length - 1 ? 8 : 0,
                ),
                child: SessionTile(
                  session: session,
                  isArchived: isArchived,
                  isActive: activityInfo != null,
                  unseen: loaded.isSessionUnseen(session: session),
                  selected: selectedSessionId == session.id,
                  awaitingInput: activityInfo?.awaitingInput ?? false,
                  isRetrying: activityInfo?.isRetrying ?? false,
                  backgroundTaskCount: activityInfo?.backgroundTaskCount ?? 0,
                  onTap: onSessionTap == null ? null : () => onSessionTap(session: session),
                  // The list's context, not the row's: archive/delete
                  // unmount the row before their follow-ups run.
                  menuEntries: () => actionDispatcher.sessionMenuEntries(context: context, session: session),
                  onArchive: () => actionDispatcher.handleSessionArchive(context: context, session: session),
                  onDelete: () => actionDispatcher.handleSessionDelete(context: context, session: session),
                  onToggleUnread: () => actionDispatcher.handleSessionToggleUnread(
                    context: context,
                    session: session,
                  ),
                ),
              );
            },
          ),
          if (loaded.sessions.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: loaded.showArchived ? archivedEmptyState : SessionEmptyState(projectName: projectName),
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
