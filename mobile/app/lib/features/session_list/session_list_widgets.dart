part of "session_list_screen.dart";

class _SessionTile extends StatelessWidget {
  final String projectId;
  final Session session;
  final bool isArchived;
  final bool isActive;
  final bool awaitingInput;
  final int backgroundTaskCount;
  final VoidCallback onLongPress;
  final VoidCallback onSwipe;

  const _SessionTile({
    required this.projectId,
    required this.session,
    required this.isArchived,
    required this.isActive,
    this.awaitingInput = false,
    this.backgroundTaskCount = 0,
    required this.onLongPress,
    required this.onSwipe,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final updatedAt = session.time?.updated;
    final filesChanged = session.summary?.files ?? 0;

    return Dismissible(
      key: ValueKey(session.id),
      direction: .startToEnd,
      confirmDismiss: (_) async {
        onSwipe();
        return false;
      },
      background: ColoredBox(
        color: context.zyra.colors.bgPrimary,
        child: Align(
          alignment: .centerLeft,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 24),
            child: Icon(
              isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              color: context.zyra.colors.textPrimary,
            ),
          ),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: context.zyra.colors.bgBrandSolid,
          child: Icon(
            Icons.chat_outlined,
            color: context.zyra.colors.textPrimary,
          ),
        ),
        title: Text(session.title ?? loc.sessionListUntitled),
        subtitle: Column(
          crossAxisAlignment: .start,
          children: [
            if (updatedAt != null)
              Text(
                loc.sessionListUpdated(_formatTimestamp(ms: updatedAt)),
                style: context.zyra.textTheme.textXs.regular.copyWith(
                  color: context.zyra.colors.borderPrimary,
                ),
              ),
            if (filesChanged > 0)
              Text(
                loc.sessionListFilesChanged(filesChanged),
                style: context.zyra.textTheme.textXs.regular,
              ),
            if (session.pullRequest case final pr?) PrStatusRow(pr: pr),
            if (isActive)
              _buildActivityRow(
                context: context,
                loc: loc,
                awaitingInput: awaitingInput,
                backgroundTaskCount: backgroundTaskCount,
              ),
          ],
        ),
        isThreeLine: updatedAt != null && (filesChanged > 0 || isActive || session.pullRequest != null),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.pushRoute(
            AppRoute.sessionDetail(
              projectId: projectId,
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

Widget _buildActivityRow({
  required BuildContext context,
  required AppLocalizations loc,
  required bool awaitingInput,
  required int backgroundTaskCount,
}) {
  final color = awaitingInput ? kStatusAmber : context.zyra.colors.bgBrandSolid;
  final label = awaitingInput ? loc.sessionListAwaitingInput : loc.sessionListRunning;

  return Row(
    children: [
      Icon(Icons.circle, size: 8, color: color),
      const SizedBox(width: 4),
      Text(
        label,
        style: context.zyra.textTheme.textXs.regular.copyWith(color: color),
      ),
      if (backgroundTaskCount > 0) ...[
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
          child: Icon(Icons.circle, size: 3, color: color),
        ),
        Text(
          loc.sessionListBackgroundTasks(backgroundTaskCount),
          style: context.zyra.textTheme.textXs.regular.copyWith(color: color),
        ),
      ],
    ],
  );
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
              color: context.zyra.colors.fgErrorPrimary,
            ),
            const SizedBox(height: 16),
            Text(
              loc.sessionListStaleProjectTitle,
              style: context.zyra.textTheme.textMd.bold,
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
              color: context.zyra.colors.fgErrorPrimary,
            ),
            const SizedBox(height: 16),
            Text(
              loc.sessionListErrorTitle,
              style: context.zyra.textTheme.textMd.bold,
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
