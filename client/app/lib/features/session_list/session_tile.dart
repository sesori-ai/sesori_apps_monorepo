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

/// A single session row: a title line led by the session's state icon, over an
/// indented footer with the workspace branch, pull-request status and when the
/// session last changed.
///
/// The icon slot carries the liveness the old status line spelled out: the
/// sparkle twinkles while an agent works and rests solid — the same "new
/// activity" mark the project list uses — when the session has activity the
/// user hasn't opened. Only states that need words keep them, as coloured
/// footer labels.
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
    final prego = context.prego;

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onSwipe();
        return false;
      },
      background: ColoredBox(
        color: prego.colors.bgSurface1,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 24),
            child: Icon(
              isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              color: prego.colors.textPrimary,
            ),
          ),
        ),
      ),
      // Right-click is the mouse counterpart of long-press. The row announces
      // itself as one button, so its two lines aren't separate nodes to swipe
      // past.
      child: GestureDetector(
        onSecondaryTap: openMenu,
        child: MergeSemantics(
          child: Semantics(
            button: true,
            // Ink rather than a plain colour so the tap ripple stays visible
            // over the selected tint (a widget's own colour would cover it).
            child: Ink(
              color: selected ? prego.colors.bgBrandSolid.withValues(alpha: 0.08) : null,
              child: InkWell(
                onTap: onTap,
                onLongPress: openMenu,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PregoSpacing.xl,
                    vertical: PregoSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    // A zero-width side is a single physical pixel and costs
                    // the row no height, so the divider doesn't push the list
                    // off its pitch.
                    border: Border(bottom: BorderSide(color: prego.colors.borderTertiary, width: 0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: PregoSpacing.xxs,
                    children: [
                      _titleRow(context: context),
                      _footerRow(context: context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleRow({required BuildContext context}) {
    final prego = context.prego;
    return Row(
      spacing: PregoSpacing.xxs,
      children: [
        // The slot is held open even without an icon, so titles line up down
        // the list whatever each row's state is.
        SizedBox(
          width: _iconSlotWidth,
          height: _titleLineHeight,
          child: Center(child: _stateIcon(context: context)),
        ),
        Expanded(
          child: Text(
            session.title ?? context.loc.sessionListUntitled,
            // Unopened activity leans on weight rather than a badge.
            style: (unseen ? prego.textTheme.textMd.medium : prego.textTheme.textMd.regular).copyWith(
              color: prego.colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// The session's state, told by the sparkle: twinkling while an agent works,
  /// resting solid when there is activity the user hasn't opened, absent for a
  /// quiet session. A live turn is the more informative of the two, so it wins;
  /// unseen still shows through the title's weight.
  Widget? _stateIcon({required BuildContext context}) {
    if (isActive) {
      // The twinkle is visual-only, so the merged row semantics carry the
      // words the old "Running" label used to speak.
      return Semantics(
        label: context.loc.sessionListRunning,
        child: PregoAiLoader(size: _stateIconSize, phase: PregoAiLoader.phaseFor(session.id)),
      );
    }
    if (unseen) {
      // Same contract as the project list: the resting sparkle is decorative,
      // so the spoken "New activity" label carries the unread meaning that
      // title weight alone does not announce.
      return Semantics(
        label: context.loc.sessionListNewActivity,
        child: const PregoAiLoader(size: _stateIconSize, animate: false),
      );
    }
    return null;
  }

  /// The row's second line, indented under the title: branch, pull request and
  /// any state that needs words, with the last-updated time holding the end.
  Widget _footerRow({required BuildContext context}) {
    final prego = context.prego;
    final updatedAt = session.time?.updated;
    final status = _statusLabel(context: context);
    final details = Row(
      spacing: PregoSpacing.md,
      children: [
        // The branch yields and ellipsizes when the line runs out of width —
        // branch names are the one unbounded detail — so it can't push the
        // rest out of the row.
        if (session.branchName case final branch?) Flexible(child: _BranchDetail(branch: branch)),
        if (session.pullRequest case final pr?) Flexible(flex: 2, child: PrStatusRow(pr: pr)),
        if (status != null) Flexible(child: status),
      ],
    );
    final timestamp = updatedAt == null
        ? null
        : Text(
            context.formatTimestamp(updatedAt),
            style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
          );
    final footerFontSize = prego.textTheme.textXs.regular.fontSize ?? 12;
    final stackTimestamp =
        timestamp != null &&
        (session.branchName != null || session.pullRequest != null || status != null) &&
        MediaQuery.textScalerOf(context).scale(footerFontSize) > _footerLineHeight;

    // The line box is held open even when there is nothing to say, so a quiet
    // session doesn't shrink its row out of the list's pitch. A minimum rather
    // than a fixed height: scaled-up accessibility text grows the row instead
    // of being cropped to the 1x line box.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _footerLineHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xl),
        child: stackTimestamp
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: PregoSpacing.xxs,
                children: [
                  details,
                  Align(alignment: AlignmentDirectional.centerEnd, child: timestamp),
                ],
              )
            : Row(
                spacing: PregoSpacing.md,
                children: [
                  Expanded(child: details),
                  ?timestamp,
                ],
              ),
      ),
    );
  }

  /// The states that still need words after the sparkle has said "working":
  /// input wanted, a retry loop, tasks running behind the turn. A plain
  /// running session carries no label — the twinkle is the signal.
  Widget? _statusLabel({required BuildContext context}) {
    final loc = context.loc;
    final prego = context.prego;
    final (label, color) = switch ((awaitingInput, isRetrying)) {
      (true, _) => (loc.sessionListAwaitingInput, kStatusAmber),
      (_, true) => (loc.sessionListRunningRetrying, prego.colors.fgErrorPrimary),
      _ when backgroundTaskCount > 0 => (
        loc.sessionListBackgroundTasks(backgroundTaskCount),
        prego.colors.bgBrandSolid,
      ),
      _ => (null, null),
    };
    if (label == null || color == null) return null;

    return Text(
      label,
      style: prego.textTheme.textXs.regular.copyWith(color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// The branch the session's workspace is checked out on: a git-branch mark in
/// a fixed slot, then the name.
class _BranchDetail extends StatelessWidget {
  const _BranchDetail({required this.branch});

  final String branch;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Row(
      // Hugs its content: inside the footer's Flexible slot a max-sized Row
      // would claim the whole allotment and strand its neighbours at the far
      // end.
      mainAxisSize: MainAxisSize.min,
      spacing: _detailIconGap,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: _iconSlotWidth,
            child: Center(
              child: Icon(TablerRegular.git_branch, size: _detailIconSize, color: prego.colors.textSecondary),
            ),
          ),
        ),
        Flexible(
          child: Text(
            branch,
            style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// The row's line boxes, from the type scale it renders: a 16/24 title over a
/// 12/18 footer line with 20px minimum height.
const double _titleLineHeight = 24;
const double _footerLineHeight = 20;

/// The state and detail icons sit in fixed slots so titles — and the footer
/// details under them — line up with each other down the list.
const double _iconSlotWidth = 20;

const double _stateIconSize = 14;
const double _detailIconSize = 14;

/// The design pairs a footer icon with its text tighter than any spacing
/// token.
const double _detailIconGap = 3;
