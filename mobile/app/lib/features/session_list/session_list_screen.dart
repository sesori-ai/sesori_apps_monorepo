import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/app_modal_bottom_sheet.dart";
import "../../l10n/app_localizations.dart";
import "rename_session_dialog.dart";

class SessionListScreen extends StatelessWidget {
  final String projectId;
  final String? projectName;

  const SessionListScreen({
    super.key,
    required this.projectId,
    this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SessionListCubit(
        getIt<SessionService>(),
        getIt<ProjectService>(),
        getIt<ConnectionService>(),
        getIt<SseEventRepository>(),
        projectId: projectId,
        failureReporter: getIt<FailureReporter>(),
      ),
      child: _SessionListBody(projectName: projectName),
    );
  }
}

class _SessionListBody extends StatelessWidget {
  final String? projectName;

  const _SessionListBody({this.projectName});

  void _goToNewSession(BuildContext context) {
    final projectId = context.read<SessionListCubit>().projectId;
    context.pushRoute(
      AppRoute.newSession(projectId: projectId),
    );
  }

  void _showSessionActions(BuildContext context, Session session) {
    final loc = context.loc;
    final cubit = context.read<SessionListCubit>();
    final isArchived = session.time?.archived != null;

    showAppModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Column(
          mainAxisSize: .min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(loc.rename),
              onTap: () {
                Navigator.pop(sheetContext);
                showRenameSessionDialog(
                  context: context,
                  session: session,
                  cubit: cubit,
                );
              },
            ),
            ListTile(
              leading: Icon(isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
              title: Text(isArchived ? loc.sessionListUnarchive : loc.sessionListArchive),
              onTap: () {
                Navigator.pop(sheetContext);
                if (isArchived) {
                  _unarchiveSession(context, cubit, session.id);
                } else {
                  _archiveSession(context, cubit, session.id);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outlined, color: Theme.of(context).colorScheme.error),
              title: Text(
                loc.sessionListDelete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(context, cubit, session);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _archiveSession(
    BuildContext context,
    SessionListCubit cubit,
    String sessionId,
  ) async {
    final loc = context.loc;
    final success = await cubit.archiveSession(sessionId);
    if (!success || !context.mounted) return;

    _showUndoSnackBar(context, cubit, loc.sessionListArchived);
  }

  Future<void> _unarchiveSession(
    BuildContext context,
    SessionListCubit cubit,
    String sessionId,
  ) async {
    final loc = context.loc;
    final success = await cubit.unarchiveSession(sessionId);
    if (!success || !context.mounted) return;

    // Show confirmation without undo — unarchive creates a new session
    // (via fork + delete), so the original cannot be restored.
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(loc.sessionListUnarchived)));
  }

  void _showUndoSnackBar(BuildContext context, SessionListCubit cubit, String message) {
    final loc = context.loc;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: loc.sessionListUndo,
              onPressed: () => cubit.undoLastArchiveAction(),
            ),
          ),
        )
        .closed
        .then((reason) {
          // Clear undo state only when the snackbar genuinely expired or was
          // swiped away. Skip on:
          //  - action: user pressed undo — cubit already cleared the snapshot.
          //  - remove: clearSnackBars() was called because a new archive/unarchive
          //    action replaced this snackbar — clearing now would wipe the *new*
          //    action's undo state.
          if (reason == SnackBarClosedReason.timeout || reason == SnackBarClosedReason.swipe) {
            cubit.clearLastActionUndo();
          }
        });
  }

  void _confirmDelete(BuildContext context, SessionListCubit cubit, Session session) {
    final loc = context.loc;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(loc.sessionListDeleteConfirmTitle),
          content: Text(loc.sessionListDeleteConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(loc.sessionListDeleteConfirmCancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteSession(context, cubit, session.id);
              },
              child: Text(
                loc.sessionListDeleteConfirmAction,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSession(
    BuildContext context,
    SessionListCubit cubit,
    String sessionId,
  ) async {
    final loc = context.loc;
    final success = await cubit.deleteSession(sessionId);
    if (!success || !context.mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.sessionListDeleted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionListCubit>().state;
    final title = projectName != null ? loc.sessionListTitleWithName(projectName!) : loc.sessionListTitle;

    final showArchived = state is SessionListLoaded && state.showArchived;
    final baseBranch = state is SessionListLoaded ? state.baseBranch : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            if (baseBranch != null)
              Text(
                baseBranch,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(showArchived ? Icons.archive : Icons.archive_outlined),
            tooltip: loc.sessionListToggleArchived,
            onPressed: state is SessionListLoaded ? () => context.read<SessionListCubit>().toggleArchived() : null,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goToNewSession(context),
        tooltip: loc.sessionListNewSession,
        child: const Icon(Icons.add),
      ),
      body: switch (state) {
        SessionListLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        SessionListLoaded(:final sessions, :final isRefreshing) => Column(
          children: [
            if (isRefreshing) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final success = await context.read<SessionListCubit>().refreshSessions();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? loc.sessionListRefreshSuccess : loc.sessionListRefreshFailed)),
                  );
                },
                child: sessions.isEmpty
                    ? CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverFillRemaining(
                            child: Center(
                              child: Text(
                                showArchived ? loc.sessionListEmptyArchived : loc.sessionListEmpty,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final cubit = context.read<SessionListCubit>();
                          final isArchived = session.time?.archived != null;
                          final activityInfo = state.activeSessionIds[session.id];
                          return _SessionTile(
                            session: session,
                            isArchived: isArchived,
                            isActive: activityInfo != null,
                            backgroundTaskCount: activityInfo?.backgroundTaskCount ?? 0,
                            onLongPress: () => _showSessionActions(context, session),
                            onSwipe: () => isArchived
                                ? _unarchiveSession(context, cubit, session.id)
                                : _archiveSession(context, cubit, session.id),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
        SessionListStaleProject() => _StaleProjectView(
          onBack: () => context.pop(),
        ),
        SessionListFailed(:final error) => _ErrorView(
          error: error,
          onRetry: () => context.read<SessionListCubit>().loadSessions(),
        ),
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Session session;
  final bool isArchived;
  final bool isActive;
  final int backgroundTaskCount;
  final VoidCallback onLongPress;
  final VoidCallback onSwipe;

  const _SessionTile({
    required this.session,
    required this.isArchived,
    required this.isActive,
    this.backgroundTaskCount = 0,
    required this.onLongPress,
    required this.onSwipe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    final updatedAt = session.time?.updated;
    final filesChanged = session.summary?.files ?? 0;

    return Dismissible(
      key: ValueKey(session.id),
      direction: .startToEnd,
      confirmDismiss: (_) async {
        onSwipe();
        // Return false — the cubit removes the item from the list, so we
        // don't need Dismissible to animate the removal itself.
        return false;
      },
      background: ColoredBox(
        color: theme.colorScheme.secondaryContainer,
        child: Align(
          alignment: .centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Icon(
              isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.chat_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(session.title ?? loc.sessionListUntitled),
        subtitle: Column(
          crossAxisAlignment: .start,
          children: [
            if (updatedAt != null)
              Text(
                loc.sessionListUpdated(_formatTimestamp(updatedAt)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            if (filesChanged > 0)
              Text(
                loc.sessionListFilesChanged(filesChanged),
                style: theme.textTheme.bodySmall,
              ),
            if (isActive)
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    loc.sessionListRunning,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (backgroundTaskCount > 0) ...[
                    Text(
                      " \u00b7 ",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      loc.sessionListBackgroundTasks(backgroundTaskCount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
        isThreeLine: updatedAt != null && (filesChanged > 0 || isActive),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.pushRoute(
            AppRoute.sessionDetail(
              projectId: session.projectID,
              sessionId: session.id,
              sessionTitle: session.title ?? "",
            ),
          );
        },
        onLongPress: onLongPress,
      ),
    );
  }

  String _formatTimestamp(int ms) {
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return "just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${diff.inHours}h ago";
    if (diff.inDays < 30) return "${diff.inDays}d ago";
    return "${date.year}-${date.month.toString().padLeft(2, "0")}-${date.day.toString().padLeft(2, "0")}";
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
          mainAxisSize: .min,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              loc.sessionListStaleProjectTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(loc.sessionListStaleProjectMessage, textAlign: .center),
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
  final ApiError error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: .min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              loc.sessionListErrorTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(_describeError(loc, error), textAlign: .center),
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

  String _describeError(AppLocalizations loc, ApiError error) => switch (error) {
    NotAuthenticatedError() => loc.apiErrorNotAuthenticated,
    NonSuccessCodeError(:final errorCode, :final rawErrorString) =>
      rawErrorString != null
          ? loc.connectErrorNonSuccessCodeWithBody(
              errorCode,
              rawErrorString,
            )
          : loc.connectErrorNonSuccessCode(errorCode),
    DartHttpClientError(:final innerError) => loc.connectErrorConnectionFailed(innerError.toString()),
    JsonParsingError() => loc.connectErrorUnexpectedFormat,
    GenericError() => loc.connectErrorUnknown,
  };
}
