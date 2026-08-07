import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";
import "../../core/status_colors.dart";
import "pr_status_row.dart";
import "session_row_metrics.dart";

/// Builds the long-press actions for a session row. It is a builder rather than
/// a ready-made list because the entries are owned by the screen's action
/// dispatcher, while the list supplies the session and the context they act
/// against. The context must be the list's, not the row's: archive and delete
/// hide the row optimistically, unmounting it before their cubit calls resolve,
/// which would silently skip the follow-up the actions run afterwards (undo
/// snackbar, closing a deleted session's detail route).
typedef SessionMenuEntriesBuilder = List<PregoMenuEntry> Function(BuildContext context, Session session);

/// A single session row: a title line led by the harness driving the session
/// and ended by how it is doing, over an indented footer with the workspace
/// branch and pull-request status.
///
/// The title line's two ends answer different questions. The leading slot says
/// which backend owns the session, so a list mixing harnesses stays readable
/// at a glance. The trailing slot carries the liveness the old status line
/// spelled out: the sparkle twinkles while an agent works and rests solid —
/// the same "new activity" mark the project list uses — when the session has
/// activity the user hasn't opened, and gives way to when the session last
/// changed once there is neither. Only states that need words keep them, as
/// coloured footer labels.
///
/// Tapping opens the session; long-pressing — or right-clicking with a mouse —
/// opens its actions in a [PregoAnchorMenu] anchored to the row, which blurs
/// the rest of the list back and holds this row sharp so the session being
/// acted on stays in view.
///
/// The frequent actions are also behind swipes ([PregoSwipeActions]): toward
/// the start edge an unarchived row opens on a delete pill and an archive
/// pill, with a full swipe committing the archive — which is confirmed by a
/// sheet, so the quick path never finalizes anything on its own. An archived
/// row has no archive action left and opens on delete alone. Toward the end
/// edge the row opens on the mail-style read toggle, committed by a full swipe
/// likewise. The swipes are the quick paths; the menu stays the discoverable
/// and assistive one.
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
  /// like [onTap] and the swipe callbacks (see [SessionMenuEntriesBuilder]).
  final List<PregoMenuEntry> Function() menuEntries;

  /// Archives this session: the trailing swipe's primary pill on an
  /// unarchived row, which is also what a full swipe commits there.
  final VoidCallback onArchive;

  /// Deletes this session, from the trailing swipe's destructive pill.
  final VoidCallback onDelete;

  /// Flips this session's read state, from the leading swipe.
  final VoidCallback onToggleUnread;

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
    required this.onArchive,
    required this.onDelete,
    required this.onToggleUnread,
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

    return PregoSwipeActions(
      showBottomHairline: true,
      // Archiving is permanent, so an archived row has no archive action left:
      // delete moves up into the primary slot and its full swipe still opens
      // the same confirmation sheet, never destroying anything unconfirmed.
      actionsBuilder: (context, close) => [
        if (!isArchived) _deleteAction(context: context, close: close),
      ],
      primaryActionBuilder: (context, close) => isArchived
          ? _deleteAction(context: context, close: close)
          : _archiveAction(context: context, close: close),
      onFullSwipe: isArchived ? onDelete : onArchive,
      leadingPrimaryActionBuilder: (context, close) => _markUnreadAction(context: context, close: close),
      onLeadingFullSwipe: onToggleUnread,
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PregoSpacing.xl,
                    vertical: PregoSpacing.lg,
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

  /// The swipe strip's delete pill. It opens the same confirmation flow as the
  /// menu entry, so it is safe even as an archived row's full-swipe commit.
  Widget _deleteAction({required BuildContext context, required VoidCallback close}) => _actionPill(
    label: context.loc.sessionListDelete,
    icon: TablerRegular.trash,
    type: PregoButtonsSolidType.destructive,
    close: close,
    onPressed: onDelete,
  );

  /// The swipe strip's archive pill — the primary action on an unarchived
  /// row, which is also what a full swipe commits. Sized by its own content at
  /// rest; when [PregoSwipeActions] widens its box during an overdrag, the
  /// button's centered content rides the stretch.
  Widget _archiveAction({required BuildContext context, required VoidCallback close}) {
    return _actionPill(
      label: context.loc.sessionListArchive,
      icon: TablerRegular.archive,
      type: PregoButtonsSolidType.warning,
      close: close,
      onPressed: onArchive,
    );
  }

  /// The leading swipe's single action, the mail-app read toggle: label and
  /// icon follow the row's current unseen state.
  Widget _markUnreadAction({required BuildContext context, required VoidCallback close}) {
    final loc = context.loc;
    return _actionPill(
      label: unseen ? loc.sessionListMarkRead : loc.sessionListMarkUnread,
      icon: unseen ? TablerRegular.mail_opened : TablerRegular.mail,
      close: close,
      onPressed: onToggleUnread,
    );
  }

  /// Builds one of the swipe strip's pills: primary hierarchy and medium
  /// size are shared by all three, and [close] always settles the row shut
  /// before [onPressed] dispatches — leaving label, icon, tone and the
  /// callback itself as the only real differences between them.
  Widget _actionPill({
    required String label,
    required IconData icon,
    PregoButtonsSolidType type = PregoButtonsSolidType.regular,
    required VoidCallback close,
    required VoidCallback onPressed,
  }) {
    return PregoButtonsSolid(
      label: label,
      leadingIcon: icon,
      hierarchy: PregoButtonsSolidHierarchy.primary,
      type: type,
      size: PregoButtonsSolidSize.md,
      onPressed: () {
        close();
        onPressed();
      },
    );
  }

  Widget _titleRow({required BuildContext context}) {
    final prego = context.prego;
    return Row(
      children: [
        // Which harness is driving the session, in a fixed slot so titles line
        // up down the list however many backends it mixes. The logo is the
        // only thing on the row that says which one, so it is named in words
        // too — the glyph itself stays decorative.
        Semantics(
          label: context.loc.sessionListHarness(PregoBrandLogo.displayNameFor(session.pluginId)),
          child: SizedBox(
            width: kSessionRowIconSlotWidth,
            height: _titleLineHeight,
            child: Center(
              child: PregoBrandLogo(
                pluginId: session.pluginId,
                size: _brandLogoSize,
                color: context.prego.colors.textSecondary,
              ),
            ),
          ),
        ),
        SizedBox(width: prego.spacing.xs),
        Expanded(child: _title(context: context)),
        _trailingSlot(context: context),
      ],
    );
  }

  /// The session's title, cut off by a fade rather than an ellipsis: a long
  /// title trails away under the row's trailing slot instead of stopping on a
  /// hard "…".
  ///
  /// [TextOverflow.fade] rather than a mask of our own: the paragraph already
  /// has the layout, so it can fade the glyphs — which a scrim painted in the
  /// row's colour could not, it would band against the selected row's tint,
  /// the dark theme and the glass scaffold — and it only builds the shader for
  /// the titles that really did overflow, without a row paying to be measured
  /// twice. The ramp is an ellipsis wide rather than the design's, which is
  /// the price of that.
  Widget _title({required BuildContext context}) {
    final prego = context.prego;

    return Text(
      session.title ?? context.loc.sessionListUntitled,
      // Unopened activity leans on weight rather than a badge.
      style: (unseen ? prego.textTheme.textMd.medium : prego.textTheme.textMd.regular).copyWith(
        color: prego.colors.textPrimary,
      ),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
    );
  }

  /// The end of the title line: the state sparkle when the session has one to
  /// show, otherwise when it last changed. They share the slot rather than
  /// stack — a working session is the more urgent thing to say, so it takes
  /// the space and the time rides along in the slot's spoken label instead.
  Widget _trailingSlot({required BuildContext context}) {
    final prego = context.prego;
    final updatedAt = session.time?.updated;
    final spokenTime = updatedAt == null ? null : context.formatTimestamp(updatedAt);
    final state = _state(context: context);

    if (state != null) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: PregoSpacing.md),
        child: SizedBox(
          width: kSessionRowIconSlotWidth,
          height: _titleLineHeight,
          // Nested rather than one composed string so the state is spoken
          // first: it is why the time lost the slot, so it leads the pair.
          child: Center(
            child: Semantics(
              label: state.label,
              child: Semantics(label: spokenTime, child: state.sparkle),
            ),
          ),
        ),
      );
    }
    if (updatedAt == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: PregoSpacing.md),
      child: Text(
        context.formatTimestampCompact(ms: updatedAt),
        // "2d" is a glance mark; assistive technology hears the phrase.
        semanticsLabel: spokenTime,
        style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
        // Past the relative window this is a date, and some locales write
        // those with spaces; it holds the line rather than wrapping the row
        // open on the title's behalf.
        maxLines: 1,
        softWrap: false,
      ),
    );
  }

  /// The session's state, told by the sparkle: twinkling while an agent works,
  /// resting solid when there is activity the user hasn't opened, absent for a
  /// quiet session. A live turn is the more informative of the two, so it wins;
  /// unseen still shows through the title's weight.
  ///
  /// The sparkle is visual-only either way, so it never travels without the
  /// words that say what it means — the caller has both or neither.
  ({String label, Widget sparkle})? _state({required BuildContext context}) {
    if (isActive) {
      return (
        label: context.loc.sessionListRunning,
        sparkle: PregoAiLoader(size: _stateIconSize, phase: PregoAiLoader.phaseFor(session.id)),
      );
    }
    if (unseen) {
      // Same contract as the project list: the resting sparkle carries the
      // unread meaning that title weight alone does not announce.
      return (
        label: context.loc.sessionListNewActivity,
        sparkle: const PregoAiLoader(size: _stateIconSize, animate: false),
      );
    }
    return null;
  }

  /// The row's second line, indented under the title: branch, pull request and
  /// any state that needs words. When the session last changed is told by the
  /// title line's trailing slot, not here.
  Widget _footerRow({required BuildContext context}) {
    final status = _statusLabel(context: context);

    // The line box is held open even when there is nothing to say, so a quiet
    // session doesn't shrink its row out of the list's pitch. A minimum rather
    // than a fixed height: scaled-up accessibility text grows the row instead
    // of being cropped to the 1x line box.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _footerLineHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: PregoSpacing.x2l),
        child: Row(
          spacing: PregoSpacing.md,
          children: [
            // The branch yields and ellipsizes when the line runs out of width
            // — branch names are the one unbounded detail — so it can't push
            // the rest out of the row.
            if (session.branchName case final branch?) Flexible(child: _BranchDetail(branch: branch)),
            if (session.pullRequest case final pr?) Flexible(flex: 2, child: PrStatusRow(pr: pr)),
            if (status != null) Flexible(child: status),
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
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: kSessionRowIconSlotWidth,
            child: Center(
              child: Icon(TablerRegular.git_branch, size: kSessionRowDetailIconSize, color: prego.colors.textSecondary),
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

const double _brandLogoSize = 12;
const double _stateIconSize = 16;
