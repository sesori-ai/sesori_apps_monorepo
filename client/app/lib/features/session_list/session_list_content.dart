import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/constants.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/extensions/remote_failure_x.dart";
import "../../core/routing/app_router.dart";
import "session_empty_state.dart";
import "session_list_screen.dart";
import "session_tile.dart";

const _actionDispatcher = SessionListActionDispatcher();

/// Pull-to-refresh handler shared by [SessionListScaffold] and
/// [SessionListPanel]: re-fetches the session list and reports the outcome via
/// a snackbar. Both hosts own their own scroll view (and thus their own
/// [RefreshIndicator]), so the refresh action lives here, next to the content.
Future<void> refreshSessionList(BuildContext context) async {
  final loc = context.loc;
  final success = await context.read<SessionListCubit>().refreshSessions(waitForPrData: true);
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(success ? loc.sessionListRefreshSuccess : loc.sessionListRefreshFailed),
      duration: kSnackBarDuration,
    ),
  );
}

class SessionListContent extends StatelessWidget {
  final String? projectName;
  final String? selectedSessionId;
  final ValueChanged<Session> onSessionTap;
  final SessionMenuEntriesBuilder sessionMenuEntries;

  const SessionListContent({
    super.key,
    required this.projectName,
    this.selectedSessionId,
    required this.onSessionTap,
    required this.sessionMenuEntries,
  });

  /// Returns the page content as a single sliver per state, so it slots
  /// directly into [PregoGlassScaffold]'s scroll view. Pull-to-refresh and the
  /// `isRefreshing` progress bar are owned by [SessionListScaffold]; this only
  /// renders the list/empty/error content.
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionListCubit>().state;

    return switch (state) {
      SessionListLoading() => SliverToBoxAdapter(
        child: PregoSkeletonList(semanticLabel: loc.sessionListLoadingSemantics),
      ),
      final SessionListLoaded loaded =>
        loaded.sessions.isEmpty
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: loaded.showArchived
                    ? Center(child: Text(loc.sessionListEmptyArchived))
                    : SessionEmptyState(projectName: projectName),
              )
            : SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                sliver: SliverList.builder(
                  itemCount: loaded.sessions.length,
                  // Lets Flutter relocate a keyed row after the list reorders
                  // (sessions live-sort by activity), so a swiped-open row
                  // keeps its state with its session instead of at its old
                  // index.
                  findChildIndexCallback: (key) {
                    if (key is! ValueKey<String>) return null;
                    final index = loaded.sessions.indexWhere((session) => session.id == key.value);
                    return index == -1 ? null : index;
                  },
                  itemBuilder: (_, index) {
                    final session = loaded.sessions[index];
                    final isArchived = session.time?.archived != null;
                    final activityInfo = loaded.activeSessionIds[session.id];

                    return SessionTile(
                      // Keyed so findChildIndexCallback above can remap this
                      // row to its new index when the list reorders around it.
                      key: ValueKey(session.id),
                      session: session,
                      isArchived: isArchived,
                      isActive: activityInfo != null,
                      unseen: loaded.isSessionUnseen(session: session),
                      selected: selectedSessionId == session.id,
                      awaitingInput: activityInfo?.awaitingInput ?? false,
                      isRetrying: activityInfo?.isRetrying ?? false,
                      backgroundTaskCount: activityInfo?.backgroundTaskCount ?? 0,
                      onTap: () => onSessionTap(session),
                      // The list's context, not the row's: archive/delete
                      // unmount the row before their follow-ups run.
                      menuEntries: () => sessionMenuEntries(context, session),
                      onArchive: () => _actionDispatcher.handleSessionArchive(context: context, session: session),
                      onDelete: () => _actionDispatcher.handleSessionDelete(context: context, session: session),
                      onToggleUnread: () =>
                          _actionDispatcher.handleSessionToggleUnread(context: context, session: session),
                    );
                  },
                ),
              ),
      SessionListStaleProject() => SliverFillRemaining(
        hasScrollBody: false,
        child: _StaleProjectView(onBack: () => _exitSessionShell(context)),
      ),
      SessionListFailed(:final reason) => SliverFillRemaining(
        hasScrollBody: false,
        child: _ErrorView(
          reason: reason,
          onRetry: () => context.read<SessionListCubit>().retryLoadSessions(),
        ),
      ),
    };
  }

  void _exitSessionShell(BuildContext context) {
    // Stale-project UI can render in the left split pane; pop the root stack
    // so the whole shell exits instead of only the pane navigator. Cold-start
    // shells have no root ancestor, so fall back to the projects route.
    // ignore: no_slop_linter/avoid_navigator_of, root navigator pop is required to exit the split shell from left-pane stale state
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    } else {
      context.goRoute(const AppRoute.projects());
    }
  }
}

class _StaleProjectView extends StatelessWidget {
  final VoidCallback onBack;

  const _StaleProjectView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_outlined, size: 48, color: context.prego.colors.fgErrorPrimary),
            const SizedBox(height: 16),
            Text(loc.sessionListStaleProjectTitle, style: context.prego.textTheme.textMd.bold),
            const SizedBox(height: 8),
            Text(loc.sessionListStaleProjectMessage, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: Text(loc.sessionListStaleProjectBack),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final RemoteFailureReason reason;
  final VoidCallback onRetry;

  const _ErrorView({required this.reason, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.prego.colors.fgErrorPrimary),
            const SizedBox(height: 16),
            Text(loc.sessionListErrorTitle, style: context.prego.textTheme.textMd.bold),
            const SizedBox(height: 8),
            Text(
              reason.localizedMessage(loc),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(loc.sessionListRetry),
            ),
          ],
        ),
      ),
    );
  }
}
