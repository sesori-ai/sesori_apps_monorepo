import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../core/extensions/build_context_x.dart";
import "../../core/status_colors.dart";
import "pr_status_row.dart";

class SessionTile extends StatelessWidget {
  final Session session;
  final bool isArchived;
  final bool isActive;
  final bool selected;
  final bool awaitingInput;
  final int backgroundTaskCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSwipe;

  const SessionTile({
    super.key,
    required this.session,
    required this.isArchived,
    required this.isActive,
    this.selected = false,
    this.awaitingInput = false,
    this.backgroundTaskCount = 0,
    required this.onTap,
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
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onSwipe();
        return false;
      },
      background: ColoredBox(
        color: context.zyra.colors.bgPrimary,
        child: Align(
          alignment: Alignment.centerLeft,
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
        selected: selected,
        selectedTileColor: context.zyra.colors.bgBrandSolid.withValues(alpha: 0.08),
        leading: CircleAvatar(
          backgroundColor: context.zyra.colors.bgBrandSolid,
          child: Icon(
            Icons.chat_outlined,
            color: context.zyra.colors.fgWhite,
          ),
        ),
        title: Text(session.title ?? loc.sessionListUntitled),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (updatedAt != null)
              Text(
                loc.sessionListUpdated(context.formatTimestamp(updatedAt)),
                style: context.zyra.textTheme.textXs.regular.copyWith(
                  color: context.zyra.colors.textSecondary,
                ),
              ),
            if (filesChanged > 0)
              Text(
                loc.sessionListFilesChanged(filesChanged),
                style: context.zyra.textTheme.textXs.regular,
              ),
            if (session.pullRequest case final pr?) PrStatusRow(pr: pr),
            if (isActive)
              _ActivityRow(
                awaitingInput: awaitingInput,
                backgroundTaskCount: backgroundTaskCount,
              ),
          ],
        ),
        isThreeLine: updatedAt != null && (filesChanged > 0 || isActive || session.pullRequest != null),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final bool awaitingInput;
  final int backgroundTaskCount;

  const _ActivityRow({required this.awaitingInput, required this.backgroundTaskCount});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
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
}
