part of "session_list_screen.dart";

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
            padding: const EdgeInsetsDirectional.only(start: 24),
            child: Icon(
              isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
      child: ListTile(
        leading: switch (session.pullRequest) {
          final pr? => PrStatusAvatar(pr: pr),
          null => CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.chat_outlined,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        },
        title: Text(session.title ?? loc.sessionListUntitled),
        subtitle: Column(
          crossAxisAlignment: .start,
          children: [
            if (updatedAt != null)
              Text(
                loc.sessionListUpdated(_formatTimestamp(ms: updatedAt)),
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
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.circle,
                        size: 3,
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
              readOnly: false,
            ),
          );
        },
        onLongPress: onLongPress,
      ),
    );
  }
}

String _formatTimestamp({required int ms}) {
  final date = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inMinutes < 1) return "just now";
  if (diff.inHours < 1) return "${diff.inMinutes}m ago";
  if (diff.inDays < 1) return "${diff.inHours}h ago";
  if (diff.inDays < 30) return "${diff.inDays}d ago";
  return "${date.year}-${date.month.toString().padLeft(2, "0")}-${date.day.toString().padLeft(2, "0")}";
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
            Text(
              _describeError(loc: loc, error: error),
              textAlign: .center,
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

  String _describeError({required AppLocalizations loc, required ApiError error}) => switch (error) {
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
    EmptyResponseError() => loc.connectErrorUnexpectedFormat,
    GenericError() => loc.connectErrorUnknown,
  };
}
