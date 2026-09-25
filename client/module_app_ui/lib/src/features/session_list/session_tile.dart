import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "pr_status_row.dart";
import "session_scheduled_resume.dart";

/// Builds the long-press actions for a session row. It is a builder rather than
/// a ready-made list because the entries are owned by the screen's action
/// dispatcher, while the list supplies the session and the context they act
/// against. The context must be the list's, not the row's: archive and delete
/// hide the row optimistically, unmounting it before their cubit calls resolve,
/// which would silently skip the follow-up the actions run afterwards (undo
/// snackbar, closing a deleted session's detail route).
typedef SessionOpenedCallback = void Function({required Session session});

/// A single session row: a status slot, the title and when the session last
/// changed, over one tertiary meta line with the harness, branch and pull
/// request.
///
/// The leading slot says how the session is doing: the sparkle rotates while
/// an agent works and rests solid — the same "new activity" mark the project
/// list uses — when the session has activity the user hasn't opened; an amber
/// dot means it waits for the user. A quiet session leaves the slot empty, so
/// titles still line up. The time always shows at the trailing edge; a quiet
/// session with a scheduled auto-continuation shows when it resumes. States
/// that need words lead the meta line in their colour.
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
///
/// Under a [PregoInteractionMode.pointer] scope the row is denser, and hovering
/// or focusing it swaps the time for its read toggle and Archive.
class const SessionTile({
  super.key,
  required final Session session,
  required final bool isArchived,

  /// The service-owned running classification: an active session that only
  /// awaits input is not running.
  required final bool isRunning,
  final bool unseen = false,
  final bool selected = false,
  final bool awaitingInput = false,
  final bool isRetrying = false,
  final int backgroundTaskCount = 0,

  /// Opens the session when the product shell provides a detail destination.
  /// Desktop leaves this null until the transcript slice lands.
  required final VoidCallback? onTap,

  /// Builds this row's long-press actions; the session — and the stable
  /// context the actions run against — are already closed over by the list,
  /// like [onTap] and the swipe callbacks.
  required final List<PregoMenuEntry> Function() menuEntries,

  /// Archives this session: the trailing swipe's primary pill on an
  /// unarchived row, which is also what a full swipe commits there.
  required final VoidCallback onArchive,

  /// Deletes this session, from the trailing swipe's destructive pill.
  required final VoidCallback onDelete,

  /// Flips this session's read state, from the leading swipe.
  required final VoidCallback onToggleUnread,
}) extends StatelessWidget {
  /// Wide enough for the longest action label ("Mark as unread") without the
  /// panel spanning the row it is anchored to.
  static const double _menuWidth = 220;

  @override
  Widget build(BuildContext context) {
    return PregoAnchorMenu(
      flat: true,
      menuWidth: _menuWidth,
      acquireOpenLease: null,
      // Holds this row sharp while the rest of the list blurs back, so which
      // session the actions will hit is unambiguous.
      spotlight: PregoMenuSpotlight.listRow,
      entriesBuilder: menuEntries,
      triggerBuilder: (context, openMenu) {
        if (PregoInteractionScope.of(context) != PregoInteractionMode.pointer) {
          return _buildRow(context: context, openMenu: openMenu, pointer: false, revealActions: false);
        }
        return _PointerReveal(
          builder: (context, revealed) =>
              _buildRow(context: context, openMenu: openMenu, pointer: true, revealActions: revealed),
        );
      },
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required VoidCallback openMenu,
    required bool pointer,
    required bool revealActions,
  }) {
    final prego = context.prego;

    return PregoSwipeActions(
      showBottomHairline: true,
      // Archiving is permanent, so an archived row has no archive action left:
      // delete moves up into the primary slot and its full swipe still opens
      // the same confirmation sheet, never destroying anything unconfirmed.
      actionsBuilder: (context, close) => [
        if (!isArchived) _deleteAction(context: context, close: close),
      ],
      primaryActionBuilder: (context, close) =>
          isArchived ? _deleteAction(context: context, close: close) : _archiveAction(context: context, close: close),
      onFullSwipe: isArchived ? onDelete : onArchive,
      leadingPrimaryActionBuilder: (context, close) => _markUnreadAction(context: context, close: close),
      onLeadingFullSwipe: onToggleUnread,
      // Right-click is the mouse counterpart of long-press. The row merges its
      // two lines into one semantics node and announces a button only when the
      // shell provides a detail action.
      child: GestureDetector(
        onSecondaryTap: openMenu,
        child: MergeSemantics(
          child: Semantics(
            button: onTap != null,
            // Ink rather than a plain colour so the tap ripple stays visible
            // over the selected tint (a widget's own colour would cover it).
            child: Ink(
              color: selected ? prego.colors.bgBrandSolid.withValues(alpha: 0.08) : null,
              child: InkWell(
                // Long-press keeps the ink enabled, so the arrow must be chosen when a click does nothing.
                mouseCursor: onTap == null ? SystemMouseCursors.basic : WidgetStateMouseCursor.clickable,
                onTap: onTap,
                onLongPress: openMenu,
                hoverColor: pointer ? prego.colors.bgSecondaryHover : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: PregoSpacing.xl,
                    vertical: pointer ? PregoSpacing.xs : PregoSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: pointer ? 0 : PregoSpacing.xxs,
                    children: [
                      _titleRow(context: context, pointer: pointer, revealActions: revealActions),
                      _metaLine(context: context, pointer: pointer),
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

  Widget _titleRow({required BuildContext context, required bool pointer, required bool revealActions}) {
    final lineHeight = pointer ? _pointerTitleLineHeight : _titleLineHeight;
    return Row(
      spacing: PregoSpacing.xs,
      children: [
        // Reserved when quiet, so titles line up down the list.
        SizedBox(
          width: _statusSlotSize,
          height: lineHeight,
          child: switch (_state(context: context)) {
            final state? => Center(
              child: Semantics(label: state.label, child: state.mark),
            ),
            null => null,
          },
        ),
        Expanded(
          child: _title(context: context, pointer: pointer),
        ),
        if (revealActions) _hoverActions(context: context) else ?_time(context: context),
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
  Widget _title({required BuildContext context, required bool pointer}) {
    final prego = context.prego;
    final size = pointer ? prego.textTheme.textSm : prego.textTheme.textMd;

    return Text(
      session.title ?? context.loc.sessionListUntitled,
      // Unopened activity leans on weight rather than a badge.
      style: (unseen ? size.medium : size.regular).copyWith(
        color: prego.colors.textPrimary,
      ),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
    );
  }

  /// When the session last changed, at the end of the title line, or when a
  /// quiet session will continue on its own. Waiting and running outrank a
  /// scheduled continuation.
  Widget? _time({required BuildContext context}) {
    if (!awaitingInput && !isRunning) {
      if (sessionScheduledResumeAt(view: session.autoContinuation) case final continueAt?) {
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
          child: SessionScheduledResume(continueAt: continueAt, labelled: true),
        );
      }
    }
    final prego = context.prego;
    final updatedAt = session.time?.updated;
    if (updatedAt == null) return null;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
      child: Text(
        context.formatTimestampCompact(ms: updatedAt),
        // "2d" is a glance mark; assistive technology hears the phrase.
        semanticsLabel: context.formatTimestamp(updatedAt),
        style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
        // Past the relative window this is a date, and some locales write
        // those with spaces; it holds the line rather than wrapping the row
        // open on the title's behalf.
        maxLines: 1,
        softWrap: false,
      ),
    );
  }

  /// What a hovered or focused pointer row offers in place of its time: the
  /// read toggle and, unless the row is already archived, Archive.
  Widget _hoverActions({required BuildContext context}) {
    final loc = context.loc;
    Widget action({required Key key, required String tooltip, required IconData icon, required VoidCallback onTap}) =>
        IconButton(
          key: key,
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, size: PregoIconSize.md),
          // Inside the title's line box, so revealing them never moves the row.
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
            fixedSize: const Size(28, _pointerTitleLineHeight),
            minimumSize: Size.zero,
          ),
        );
    // The row's menu stays the assistive path; merged into the row these
    // would fight its own tap action.
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          action(
            key: const Key("session-tile-hover-toggle-unread"),
            tooltip: unseen ? loc.sessionListMarkRead : loc.sessionListMarkUnread,
            icon: unseen ? TablerRegular.mail_opened : TablerRegular.mail,
            onTap: onToggleUnread,
          ),
          if (!isArchived)
            action(
              key: const Key("session-tile-hover-archive"),
              tooltip: loc.sessionListArchive,
              icon: TablerRegular.archive,
              onTap: onArchive,
            ),
        ],
      ),
    );
  }

  /// The status slot's mark: an amber dot while the session waits for the
  /// user, a rotating sparkle while an agent works, a resting sparkle for activity
  /// the user hasn't opened, and nothing for a quiet session. Unseen still
  /// shows through the title's weight when another state wins.
  ///
  /// The mark is visual-only, so it never travels without the words that say
  /// what it means — the caller has both or neither.
  ({String label, Widget mark})? _state({required BuildContext context}) {
    final loc = context.loc;
    // Waiting wins: a turn blocked on the user can still count as running
    // while it retries or has background tasks.
    if (awaitingInput) {
      return (
        label: loc.sessionListAwaitingInput,
        mark: Container(
          width: _waitingDotSize,
          height: _waitingDotSize,
          decoration: BoxDecoration(shape: BoxShape.circle, color: context.prego.colors.fgWarningPrimary),
        ),
      );
    }
    if (isRunning) {
      return (label: loc.sessionListRunning, mark: const PregoAiLoader(size: _statusSlotSize));
    }
    if (unseen) {
      // Same contract as the project list: the resting sparkle carries the
      // unread meaning that title weight alone does not announce.
      return (
        label: loc.sessionListNewActivity,
        mark: const PregoAiLoader(size: _statusSlotSize, animate: false),
      );
    }
    return null;
  }

  /// The row's second line, under the title: any state that needs words, then
  /// the harness, branch and pull request, apart by middle dots.
  Widget _metaLine({required BuildContext context, required bool pointer}) {
    final prego = context.prego;
    final style = prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary);
    final status = _statusLabel(context: context);
    final details = <({int flex, Widget child})>[
      if (status != null) (flex: 1, child: status),
      (
        flex: 1,
        child: Text(
          PregoBrandLogo.displayNameFor(session.pluginId),
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      // Branch names are the one unbounded detail; both ends tell them apart.
      if (session.branchName case final branch?)
        (flex: 2, child: PregoEllipsisText(text: branch, style: style, ellipsis: PregoEllipsis.middle)),
    ];

    Widget separator() => ExcludeSemantics(
      child: Text(_separator, style: style, maxLines: 1, softWrap: false, overflow: TextOverflow.clip),
    );

    // A minimum rather than a fixed height: scaled-up accessibility text grows
    // the line instead of being cropped to the 1x line box.
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: pointer ? 0 : _metaLineHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: _statusSlotSize + PregoSpacing.xs),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              for (final (index, detail) in details.indexed)
                // Each separator yields with the detail it leads, so scaled-up
                // text shrinks details rather than overflowing the line.
                Flexible(
                  flex: detail.flex,
                  child: index == 0
                      ? detail.child
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: separator()),
                            Flexible(flex: 3, child: detail.child),
                          ],
                        ),
                ),
              // The pull request is short and bounded, so it keeps its full width
              // and the other details share what is left. The cap keeps a narrow
              // pane from handing it the whole line.
              if (session.pullRequest case final pr?)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth * _pullRequestMaxShare),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      separator(),
                      Flexible(child: PrStatusRow(pr: pr)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The states that need words: waiting for the user, a retry loop, tasks
  /// running behind the turn. A plain running session carries no label — the
  /// rotation is the signal.
  Widget? _statusLabel({required BuildContext context}) {
    final loc = context.loc;
    final prego = context.prego;
    final (label, color) = switch ((awaitingInput, isRetrying)) {
      (true, _) => (loc.sessionListWaiting, prego.colors.textWarningPrimary),
      (_, true) => (loc.sessionListRunningRetrying, prego.colors.fgErrorPrimary),
      _ when backgroundTaskCount > 0 => (
        loc.sessionListBackgroundTasks(backgroundTaskCount),
        prego.colors.bgBrandSolid,
      ),
      _ => (null, null),
    };
    if (label == null || color == null) return null;

    final text = Text(
      label,
      style: prego.textTheme.textXs.medium.copyWith(color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    // The status slot already speaks the waiting state.
    return awaitingInput ? ExcludeSemantics(child: text) : text;
  }
}

/// Whether the pointer is over the row or keyboard focus is inside it.
class const _PointerReveal({required final Widget Function(BuildContext context, bool revealed) builder})
    extends StatefulWidget {
  @override
  State<_PointerReveal> createState() => _PointerRevealState();
}

class _PointerRevealState() extends State<_PointerReveal> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: widget.builder(context, _hovered || _focused),
    ),
  );
}

/// The row's line boxes, from the type scale it renders: a 16/24 title over a
/// 12/18 meta line with 20px minimum height.
const double _titleLineHeight = 24;
const double _pointerTitleLineHeight = 20;
const double _metaLineHeight = 20;

const double _statusSlotSize = 16;
const double _waitingDotSize = 8;

/// The most of the meta line the pull request may take before it clips.
const double _pullRequestMaxShare = 0.8;

/// Between the meta line's details; a glyph, not words, so it is not translated.
const String _separator = " · ";
