import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";
import "../../core/status_colors.dart";
import "pr_status_row.dart";

/// Builds the long-press actions for a session row. It is a builder rather than
/// a ready-made list because the entries are owned by the screen's action
/// dispatcher, while the list supplies the session and the context they act
/// against. The context must be the list's, not the row's: archive and delete
/// hide the row optimistically, unmounting it before their cubit calls resolve,
/// which would silently skip the follow-up the actions run afterwards (undo
/// snackbar, closing a deleted session's detail route).
typedef SessionMenuEntriesBuilder = List<PregoMenuEntry> Function(BuildContext context, Session session);

/// A single session row.
///
/// Tapping opens the session; long-pressing — or right-clicking with a mouse —
/// opens its actions in a [PregoAnchorMenu] anchored to the row, which blurs
/// the rest of the list back and holds this row sharp so the session being
/// acted on stays in view. Swiping still archives, as before.
class SessionTile extends StatelessWidget {
  final Session session;
  final bool isArchived;
  final bool isActive;
  final bool unseen;
  final bool selected;
  final bool awaitingInput;
  final bool isRetrying;
  final int backgroundTaskCount;
  final VoidCallback onTap;

  /// Builds this row's long-press actions; the session — and the stable
  /// context the actions run against — are already closed over by the list,
  /// like [onTap] and [onSwipe] (see [SessionMenuEntriesBuilder]).
  final List<PregoMenuEntry> Function() menuEntries;

  final VoidCallback onSwipe;

  const SessionTile({
    super.key,
    required this.session,
    required this.isArchived,
    required this.isActive,
    this.unseen = false,
    this.selected = false,
    this.awaitingInput = false,
    this.isRetrying = false,
    this.backgroundTaskCount = 0,
    required this.onTap,
    required this.menuEntries,
    required this.onSwipe,
  });

  /// Wide enough for the longest action label ("Mark as unread") without the
  /// panel spanning the row it is anchored to.
  static const double _menuWidth = 220;

  @override
  Widget build(BuildContext context) {
    return PregoAnchorMenu(
      flat: true,
      menuWidth: _menuWidth,
      // Holds this row sharp while the rest of the list blurs back, so which
      // session the actions will hit is unambiguous.
      spotlight: PregoMenuSpotlight.listRow,
      entriesBuilder: menuEntries,
      triggerBuilder: (context, openMenu) => _buildRow(context: context, openMenu: openMenu),
    );
  }

  Widget _buildRow({required BuildContext context, required VoidCallback openMenu}) {
    final loc = context.loc;
    final updatedAt = session.time?.updated;

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onSwipe();
        return false;
      },
      background: ColoredBox(
        color: context.prego.colors.bgSurface1,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 24),
            child: Icon(
              isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              color: context.prego.colors.textPrimary,
            ),
          ),
        ),
      ),
      // Right-click is the mouse counterpart of long-press; ListTile has no
      // secondary-tap slot of its own, so a detector wraps it.
      child: GestureDetector(
        onSecondaryTap: openMenu,
        child: ListTile(
          selected: selected,
          selectedTileColor: context.prego.colors.bgBrandSolid.withValues(alpha: 0.08),
          leading: CircleAvatar(
            backgroundColor: context.prego.colors.bgBrandSolid,
            child: Icon(
              Icons.chat_outlined,
              color: context.prego.colors.fgWhite,
            ),
          ),
          title: Text(
            session.title ?? loc.sessionListUntitled,
            style: unseen ? context.prego.textTheme.textMd.bold : null,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (updatedAt != null)
                Text(
                  loc.sessionListUpdated(context.formatTimestamp(updatedAt)),
                  style: context.prego.textTheme.textXs.regular.copyWith(
                    color: context.prego.colors.textSecondary,
                  ),
                ),
              if (session.pullRequest case final pr?) PrStatusRow(pr: pr),
              if (isActive)
                _ActivityRow(
                  awaitingInput: awaitingInput,
                  isRetrying: isRetrying,
                  backgroundTaskCount: backgroundTaskCount,
                ),
            ],
          ),
          isThreeLine:
              [
                updatedAt != null,
                session.pullRequest != null,
                isActive,
              ].where((v) => v).length >=
              2,
          trailing: switch (unseen) {
            true => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 10, color: context.prego.colors.bgBrandSolid),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            false => const Icon(Icons.chevron_right),
          },
          onTap: onTap,
          onLongPress: openMenu,
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final bool awaitingInput;
  final bool isRetrying;
  final int backgroundTaskCount;

  const _ActivityRow({required this.awaitingInput, required this.isRetrying, required this.backgroundTaskCount});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final color = switch ((awaitingInput, isRetrying)) {
      (true, _) => kStatusAmber,
      (_, true) => context.prego.colors.fgErrorPrimary,
      _ => context.prego.colors.bgBrandSolid,
    };
    final label = switch ((awaitingInput, isRetrying)) {
      (true, _) => loc.sessionListAwaitingInput,
      (_, true) => loc.sessionListRunningRetrying,
      _ => loc.sessionListRunning,
    };

    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.prego.textTheme.textXs.regular.copyWith(color: color),
        ),
        if (backgroundTaskCount > 0) ...[
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
            child: Icon(Icons.circle, size: 3, color: color),
          ),
          Text(
            loc.sessionListBackgroundTasks(backgroundTaskCount),
            style: context.prego.textTheme.textXs.regular.copyWith(color: color),
          ),
        ],
      ],
    );
  }
}
