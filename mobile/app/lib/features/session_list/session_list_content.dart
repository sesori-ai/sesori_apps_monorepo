import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../core/constants.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/extensions/remote_failure_x.dart";
import "../../l10n/app_localizations.dart";
import "session_tile.dart";

class SessionListContent extends StatelessWidget {
  final String? selectedSessionId;
  final ValueChanged<Session> onSessionTap;
  final ValueChanged<Session> onSessionLongPress;
  final ValueChanged<Session> onSessionSwipe;

  const SessionListContent({
    super.key,
    this.selectedSessionId,
    required this.onSessionTap,
    required this.onSessionLongPress,
    required this.onSessionSwipe,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionListCubit>().state;

    return switch (state) {
      SessionListLoading() => const Center(child: CircularProgressIndicator()),
      SessionListLoaded(:final sessions, :final isRefreshing, :final showArchived, :final activeSessionIds) => Column(
        children: [
          if (isRefreshing) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _refreshSessions(context: context, loc: loc);
              },
              child: sessions.isEmpty
                  ? CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          child: Center(
                            child: Text(showArchived ? loc.sessionListEmptyArchived : loc.sessionListEmpty),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: sessions.length,
                      itemBuilder: (_, index) {
                        final session = sessions[index];
                        final isArchived = session.time?.archived != null;
                        final activityInfo = activeSessionIds[session.id];

                        return SessionTile(
                          session: session,
                          isArchived: isArchived,
                          isActive: activityInfo != null,
                          selected: selectedSessionId == session.id,
                          awaitingInput: activityInfo?.awaitingInput ?? false,
                          isRetrying: activityInfo?.isRetrying ?? false,
                          backgroundTaskCount: activityInfo?.backgroundTaskCount ?? 0,
                          onTap: () => onSessionTap(session),
                          onLongPress: () => onSessionLongPress(session),
                          onSwipe: () => onSessionSwipe(session),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      SessionListStaleProject() => _StaleProjectView(onBack: () => context.pop()),
      SessionListFailed(:final reason) => _ErrorView(
        reason: reason,
        onRetry: () => context.read<SessionListCubit>().retryLoadSessions(),
      ),
    };
  }

  Future<void> _refreshSessions({required BuildContext context, required AppLocalizations loc}) async {
    final success = await context.read<SessionListCubit>().refreshSessions(waitForPrData: true);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? loc.sessionListRefreshSuccess : loc.sessionListRefreshFailed),
        duration: kSnackBarDuration,
      ),
    );
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
            Icon(Icons.folder_off_outlined, size: 48, color: context.zyra.colors.fgErrorPrimary),
            const SizedBox(height: 16),
            Text(loc.sessionListStaleProjectTitle, style: context.zyra.textTheme.textMd.bold),
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
            Icon(Icons.error_outline, size: 48, color: context.zyra.colors.fgErrorPrimary),
            const SizedBox(height: 16),
            Text(loc.sessionListErrorTitle, style: context.zyra.textTheme.textMd.bold),
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
