import "dart:math";

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "session_scheduled_resume.dart";

/// A single session row: the harness logo, the title with its status mark and
/// when the session last changed, over one tertiary meta line with the project.
///
/// The harness logo leads in a square of one size for every harness, and is
/// the only place the row names the harness. It rests as a quiet grey glyph,
/// takes its own colours while the session has unread activity or is the open
/// one, and breathes in them while the session runs. The mark right after the title
/// says how the session is doing: the sparkle rotates while an agent works and
/// rests solid — the same "new activity" mark the project list uses — when the
/// session has activity the user hasn't opened; an amber dot means it waits
/// for the user. A long title fades out before the mark, and a quiet session
/// shows none. The time always shows at the trailing edge; a quiet session
/// with a scheduled auto-continuation shows when it resumes. States that need
/// words lead the meta line in their colour.
///
/// Tapping opens the session; long-pressing — or right-clicking with a mouse —
/// opens its actions in a [PregoAnchorMenu] anchored to the row, which blurs
/// the rest of the list back and holds this row sharp so the session being
/// acted on stays in view.
///
/// The frequent actions are also behind swipes ([PregoSwipeActions]): toward
/// the start edge an unarchived row opens on a delete pill and an archive
/// pill, with a full swipe committing the archive. Archiving happens at once
/// behind an Undo window; only a running session asks for confirmation first.
/// An archived row has no archive action left and opens on delete alone.
/// Toward the end edge the row opens on the mail-style read toggle, committed
/// by a full swipe likewise. The swipes are the quick paths; the menu stays the
/// discoverable and assistive one.
///
/// Under a [PregoInteractionMode.pointer] scope the row takes the desktop type
/// in less vertical padding, the harness logo ends the meta line under the
/// time, and hovering or focusing the row shows its read toggle and Archive
/// over that end.
class const SessionTile({
  super.key,
  required final Session session,

  /// The session's project, leading the meta line; null hides it, as in a
  /// list already filtered to one project.
  required final String? projectLabel,
  required final bool isArchived,

  /// The service-owned running classification: an active session that only
  /// awaits input is not running.
  required final bool isRunning,
  final bool unseen = false,
  final bool selected = false,
  final bool awaitingInput = false,
  final bool isRetrying = false,
  final int backgroundTaskCount = 0,

  /// Opens the session.
  required final VoidCallback onTap,

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

  /// Whether the row shows an agent at work: running, unless waiting on the
  /// user, which wins. The turning sparkle and the breathing harness logo say it.
  bool get _working => isRunning && !awaitingInput;

  /// How the harness logo shows: breathing while an agent works, in colour
  /// while the session has unread activity or is the open one, grey otherwise.
  _LogoTone get _logoTone => switch ((working: _working, standsOut: unseen || selected)) {
    (working: true, standsOut: _) => _LogoTone.live,
    (working: false, standsOut: true) => _LogoTone.colored,
    (working: false, standsOut: false) => _LogoTone.muted,
  };

  @override
  Widget build(BuildContext context) {
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: variant
    if (PregoInteractionScope.of(context) == PregoInteractionMode.pointer) {
      return _PointerRowMenu(
        menuWidth: _menuWidth,
        entriesBuilder: menuEntries,
        rowBuilder: (context, openMenu, revealed, menuOpen) => _buildRow(
          context: context,
          openMenu: openMenu,
          pointer: true,
          revealActions: revealed,
          menuOpen: menuOpen,
        ),
      );
    }
    return PregoAnchorMenu(
      flat: true,
      menuWidth: _menuWidth,
      // Holds this row sharp while the rest of the list blurs back, so which
      // session the actions will hit is unambiguous.
      spotlight: PregoMenuSpotlight.listRow,
      entriesBuilder: menuEntries,
      triggerBuilder: (context, openMenu) =>
          _buildRow(context: context, openMenu: openMenu, pointer: false, revealActions: false, menuOpen: false),
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required VoidCallback openMenu,
    required bool pointer,
    required bool revealActions,
    required bool menuOpen,
  }) {
    final prego = context.prego;

    return PregoSwipeActions(
      // Pointer rows are separated by their own rounded hover and selection.
      showBottomHairline: !pointer,
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
      // two lines into one semantics node and announces it as a button.
      child: GestureDetector(
        onSecondaryTap: openMenu,
        child: MergeSemantics(
          child: Semantics(
            button: true,
            // Ink rather than a plain colour so the tap ripple stays visible
            // over the selected tint (a widget's own colour would cover it).
            child: Padding(
              padding: pointer ? _pointerRowMargin : EdgeInsets.zero,
              child: Ink(
                color: !pointer && selected ? prego.colors.bgBrandSolid.withValues(alpha: 0.08) : null,
                decoration: pointer && selected
                    ? BoxDecoration(
                        color: prego.colors.pointerSelectionFill,
                        borderRadius: BorderRadius.circular(_pointerRowRadius),
                      )
                    : null,
                child: InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: onTap,
                  onLongPress: openMenu,
                  hoverDuration: pointer ? Duration.zero : null,
                  borderRadius: pointer ? BorderRadius.circular(_pointerRowRadius) : null,
                  hoverColor: pointer ? prego.colors.bgSecondaryHover.withValues(alpha: 0.5) : null,
                  child: Stack(
                    children: [
                      Padding(
                        padding: _rowPadding(pointer: pointer),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: _lineGap,
                          children: [
                            _titleRow(context: context, pointer: pointer),
                            _metaLine(context: context, pointer: pointer),
                          ],
                        ),
                      ),
                      // Over the meta line's end, so revealing them moves nothing
                      // and hides neither the title, its status mark nor the time.
                      if (revealActions)
                        PositionedDirectional(
                          end: PregoSpacing.xs,
                          // Centred on the meta line, at whatever text size.
                          bottom:
                              _rowVerticalPadding(pointer: true) -
                              (_hoverActionHeight - _lineHeightsOf(context: context, pointer: true).meta) / 2,
                          child: _hoverActions(context: context),
                        ),
                      // What the open menu's actions will hit, as Finder outlines the
                      // item it right-clicked.
                      if (menuOpen)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(_pointerRowRadius),
                                border: Border.all(
                                  color: prego.colors.fgBrandPrimary.withValues(alpha: 0.7),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
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

  Widget _titleRow({required BuildContext context, required bool pointer}) {
    final state = _state(context: context);
    if (pointer) return _pointerTitleRow(context: context, state: state);
    // The row's width caps a resume time, which a narrow row with large text
    // could not otherwise fit beside the title.
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        spacing: PregoSpacing.xs,
        children: [
          // The glyph is decorative, so the harness is named in words too:
          // the meta line no longer says it.
          Semantics(
            label: PregoBrandLogo.displayNameFor(session.pluginId),
            child: _HarnessLogo(pluginId: session.pluginId, tone: _logoTone),
          ),
          Expanded(
            child: _TitleLine(
              title: _title(context: context, pointer: false),
              mark: state != null ? Semantics(label: state.label, child: state.mark) : null,
            ),
          ),
          ?_time(context: context, resumeMaxWidth: constraints.maxWidth / 2, holdsColumn: false),
        ],
      ),
    );
  }

  /// A pointer row's first line: the title from the row's edge, then its state
  /// right before the time, so a quiet row gives the title that room.
  Widget _pointerTitleRow({required BuildContext context, required ({String label, Widget mark})? state}) =>
      LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: PregoSpacing.xs,
          children: [
            Expanded(child: _title(context: context, pointer: true)),
            if (state != null)
              SizedBox(
                width: _markSize,
                height: _titleLineHeightOf(pointer: true),
                child: Center(
                  child: Semantics(label: state.label, child: state.mark),
                ),
              ),
            ?_time(context: context, resumeMaxWidth: constraints.maxWidth / 2, holdsColumn: state != null),
          ],
        ),
      );

  /// The session's title, cut off by a fade rather than an ellipsis: a long
  /// title trails away before its status mark instead of stopping on a hard
  /// "…".
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
    final size = prego.textTheme.textMd;

    final title = Text(
      session.title ?? context.loc.sessionListUntitled,
      // Unopened activity leans on weight rather than a badge.
      style: (unseen ? size.medium : size.regular).copyWith(
        // Medium is the heaviest weight under a pointer, so colour says what is unread.
        color: pointer && !unseen && !awaitingInput && !isRunning && !selected
            ? Color.lerp(prego.colors.textPrimary, prego.colors.textSecondary, 0.5)
            : prego.colors.textPrimary,
      ),
      maxLines: 1,
      softWrap: false,
      overflow: pointer ? TextOverflow.clip : TextOverflow.fade,
    );
    if (!pointer) return title;
    return Tooltip(
      message: session.title ?? context.loc.sessionListUntitled,
      waitDuration: const Duration(milliseconds: 400),
      excludeFromSemantics: true,
      child: _FadingTitle(title: title),
    );
  }

  /// When the session last changed, at the end of the title line, or when a
  /// quiet session will continue on its own. Waiting and running outrank a
  /// scheduled continuation.
  Widget? _time({required BuildContext context, required double resumeMaxWidth, required bool holdsColumn}) {
    if (!awaitingInput && !isRunning) {
      if (sessionScheduledResumeAt(view: session.autoContinuation) case final continueAt?) {
        // Half the row at most: the title keeps the other half, and both ellipsize.
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: resumeMaxWidth),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
            child: SessionScheduledResume(continueAt: continueAt, labelled: true),
          ),
        );
      }
    }
    final prego = context.prego;
    final updatedAt = session.time?.updated;
    if (updatedAt == null) return null;

    return Container(
      // A fixed column beside a mark, so marks line up down the list; a quiet row's
      // title has that room instead.
      constraints: BoxConstraints(minWidth: holdsColumn ? _pointerTimeWidth : 0),
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
      child: Text(
        context.formatTimestampCompact(ms: updatedAt),
        // "2d" is a glance mark; assistive technology hears the phrase.
        semanticsLabel: context.formatTimestamp(updatedAt),
        style: _metaStyleOf(
          context: context,
          // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
          pointer: PregoInteractionScope.of(context) == PregoInteractionMode.pointer,
        ).copyWith(color: prego.colors.textSecondary, fontFeatures: const [FontFeature.tabularFigures()]),
        // Past the relative window this is a date, and some locales write
        // those with spaces; it holds the line rather than wrapping the row
        // open on the title's behalf.
        maxLines: 1,
        softWrap: false,
      ),
    );
  }

  /// What a hovered or focused pointer row offers at its end: the read toggle
  /// and, unless the row is already archived, Archive, on a scrim of the row's
  /// own fill so the project name fades out beneath them.
  Widget _hoverActions({required BuildContext context}) {
    final loc = context.loc;
    final prego = context.prego;
    final fill = selected
        ? prego.colors.pointerSelectionFill
        : Color.alphaBlend(prego.colors.bgSecondaryHover.withValues(alpha: 0.5), prego.colors.bgSecondary);
    Widget action({required Key key, required String tooltip, required IconData icon, required VoidCallback onTap}) =>
        IconButton(
          key: key,
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, size: PregoIconSize.sm),
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
            fixedSize: const Size(24, _hoverActionHeight),
            minimumSize: Size.zero,
          ),
        );
    // The row's menu stays the assistive path; merged into the row these
    // would fight its own tap action.
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: [fill.withValues(alpha: 0), fill],
            stops: const [0, 0.25],
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xl),
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
        ),
      ),
    );
  }

  /// The mark after the title: an amber dot while the session waits for the
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.prego.colors.waitingDot,
          ),
        ),
      );
    }
    if (isRunning) {
      return (label: loc.sessionListRunning, mark: const PregoAiLoader(size: _markSize));
    }
    if (unseen) {
      // Same contract as the project list: the resting sparkle carries the
      // unread meaning that title weight alone does not announce.
      return (
        label: loc.sessionListNewActivity,
        mark: const PregoAiLoader(size: _markSize, animate: false),
      );
    }
    return null;
  }

  /// The row's second line, starting under the logo: any state that needs
  /// words, then the project, then the background tasks, apart by middle dots.
  /// Under a pointer it starts on the title's edge and the harness logo ends it.
  Widget _metaLine({required BuildContext context, required bool pointer}) {
    final prego = context.prego;
    final style = _metaStyleOf(context: context, pointer: pointer).copyWith(
      color: pointer ? prego.colors.textSecondary : prego.colors.textTertiary,
    );
    final status = _statusLabel(context: context, pointer: pointer);
    final project = switch (projectLabel) {
      final project? => Text(project, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
      null => null,
    };
    final backgroundTasks = _backgroundTasks(context: context, pointer: pointer, style: style);
    if (pointer) {
      Widget separator() => ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xs),
          child: Text("·", style: style),
        ),
      );
      // Waiting and retrying never share the line with background tasks.
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: _metaLineHeightOf(pointer: pointer)),
        child: Row(
          spacing: PregoSpacing.xs,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    // The status keeps its words and the count its number; the
                    // project gives way first. Only a status too long for the
                    // whole line, with its separator, ellipsizes.
                    if (status != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: status),
                            if (project != null) separator(),
                          ],
                        ),
                      ),
                    if (project != null) Flexible(child: project),
                    if (project != null && backgroundTasks != null) separator(),
                    ?backgroundTasks,
                    // With no words at all, a line of the meta text's height holds
                    // the line box, so the row is as tall as one with words at
                    // any text size.
                    if (status == null && project == null && backgroundTasks == null)
                      SizedBox(height: context.lineHeightOf(style)),
                  ],
                ),
              ),
            ),
            // At the line's end, under the time, where the hover actions
            // cover it while the pointer is on the row.
            Semantics(
              label: PregoBrandLogo.displayNameFor(session.pluginId),
              child: _HarnessLogo(pluginId: session.pluginId, tone: _logoTone),
            ),
          ],
        ),
      );
    }
    final details = <Widget>[?status, ?project, ?backgroundTasks];

    Widget separator() => ExcludeSemantics(
      child: Text(_separator, style: style, maxLines: 1, softWrap: false, overflow: TextOverflow.clip),
    );

    // A minimum rather than a fixed height: scaled-up accessibility text grows
    // the line instead of being cropped to the 1x line box.
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: _metaLineHeightOf(pointer: pointer)),
      child: Row(
        children: [
          for (final (index, detail) in details.indexed)
            // Each separator yields with the detail it leads, so scaled-up
            // text shrinks details rather than overflowing the line.
            Flexible(
              child: index == 0
                  ? detail
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: separator()),
                        Flexible(flex: 3, child: detail),
                      ],
                    ),
            ),
          // With nothing to show, a line of the meta text's height still
          // holds the line at the current text scale, so the row stays as
          // tall as its neighbours and as the launching row it replaces.
          if (details.isEmpty) SizedBox(height: context.lineHeightOf(style)),
        ],
      ),
    );
  }

  /// The states that need words: waiting for the user and a retry loop. A
  /// plain running session has none; its turning sparkle and breathing harness logo
  /// say it.
  Widget? _statusLabel({required BuildContext context, required bool pointer}) {
    final loc = context.loc;
    final prego = context.prego;
    final (String, Color)? status = switch ((awaitingInput, isRetrying)) {
      (true, _) => (loc.sessionListWaiting, prego.colors.smallWarningText),
      (false, true) => (loc.sessionListRunningRetrying, prego.colors.fgErrorPrimary),
      (false, false) => null,
    };
    if (status case (final label, final color)) {
      final text = Text(
        label,
        style: _metaStyleOf(context: context, pointer: pointer).copyWith(fontWeight: FontWeight.w500, color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      // The status mark already speaks the waiting state.
      return awaitingInput ? ExcludeSemantics(child: text) : text;
    }
    return null;
  }

  /// The tasks running behind the turn, as a quiet count: a stack glyph and
  /// the number, in the meta line's own type. Assistive technology hears the
  /// words, which a pointer also finds in a tooltip. Waiting and retrying
  /// outrank it.
  Widget? _backgroundTasks({required BuildContext context, required bool pointer, required TextStyle style}) {
    if (backgroundTaskCount == 0 || awaitingInput || isRetrying) return null;
    final words = context.loc.sessionListBackgroundTasks(backgroundTaskCount);
    // One paragraph, so the glyph sits in the text's own line box and the
    // count clips with the text when the line runs out of room.
    final count = Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: PregoSpacing.xs),
              child: Icon(TablerRegular.stack_2, size: _backgroundTasksGlyphSize, color: style.color),
            ),
          ),
          TextSpan(text: "$backgroundTaskCount"),
        ],
      ),
      semanticsLabel: words,
      style: style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
    );
    if (!pointer) return count;
    return Tooltip(
      message: words,
      waitDuration: const Duration(milliseconds: 400),
      excludeFromSemantics: true,
      child: count,
    );
  }
}

/// A new session the bridge is still creating, in [SessionTile]'s geometry so
/// the real row takes its place without moving anything: the harness logo, the
/// first line of the first message with the running sparkle after it, and
/// "Creating…" before the harness on the meta line, with no time.
///
/// A tap answers with the row's press feedback and an alert that the session
/// cannot be opened yet. There is no menu and no swipe: both act on a session.
class const PendingSessionLaunchTile({super.key, required final LaunchingSession launch}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: variant
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    return DecoratedBox(
      // The hairline [PregoSwipeActions] draws under a real row.
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: prego.colors.borderTertiary, width: 0)),
      ),
      child: MergeSemantics(
        child: Semantics(
          button: true,
          child: Padding(
            padding: pointer ? _pointerRowMargin : EdgeInsets.zero,
            child: InkWell(
              onTap: () => PregoPopupAlertPresenter.of(context).show(title: loc.sessionListLaunchingAlert),
              hoverColor: pointer ? prego.colors.bgSecondaryHover : null,
              borderRadius: pointer ? BorderRadius.circular(_pointerRowRadius) : null,
              child: Padding(
                padding: _rowPadding(pointer: pointer),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: _lineGap,
                  children: [
                    Row(
                      spacing: PregoSpacing.xs,
                      children: [
                        // Silent, unlike the real row's: the meta line names the harness here.
                        // A pointer row ends its meta line with it instead, so its title starts at the edge.
                        // Lit, as a session being created is already at work.
                        if (!pointer) _HarnessLogo(pluginId: launch.pluginId, tone: _LogoTone.live),
                        Expanded(
                          child: _TitleLine(
                            title: Text(
                              launch.title ?? loc.sessionListUntitled,
                              style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                            ),
                            // "Creating…" already says what the sparkle means.
                            mark: const ExcludeSemantics(child: PregoAiLoader(size: _markSize)),
                          ),
                        ),
                      ],
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: _metaLineHeightOf(pointer: pointer)),
                      child: Row(
                        spacing: PregoSpacing.xs,
                        children: [
                          Expanded(
                            child: Text(
                              "${loc.sessionListCreating}$_separator${PregoBrandLogo.displayNameFor(launch.pluginId)}",
                              style: _metaStyleOf(context: context, pointer: pointer).copyWith(
                                color: prego.colors.textTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (pointer) _HarnessLogo(pluginId: launch.pluginId, tone: _LogoTone.live),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A session row's loading placeholder: the row's own insets and line boxes,
/// with a bar where the title goes and a shorter one for the details under it.
class const SessionTileSkeleton({
  super.key,

  /// The share of the row's width the title bar spans.
  required final double titleWidthFraction,
  required final double detailsWidth,
}) extends StatelessWidget {
  /// As tall as a quiet row under [context]'s pointer or touch, at its text size.
  static double heightOf({required BuildContext context}) {
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    final lines = _lineHeightsOf(context: context, pointer: pointer);
    return _rowVerticalPadding(pointer: pointer) * 2 +
        lines.title +
        _lineGap +
        lines.meta +
        (pointer ? _pointerRowMargin.vertical : 0);
  }

  @override
  Widget build(BuildContext context) {
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: variant
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    final lines = _lineHeightsOf(context: context, pointer: pointer);
    return Padding(
      padding: pointer ? _pointerRowMargin : EdgeInsets.zero,
      child: Padding(
        padding: _rowPadding(pointer: pointer),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: _lineGap,
          children: [
            SizedBox(
              height: lines.title,
              // A dot where the harness logo goes, so the title bar starts where
              // the title does.
              child: Row(
                spacing: PregoSpacing.xs,
                children: [
                  if (!pointer) const PregoSkeletonBar(height: _brandLogoSize, width: _brandLogoSize),
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: titleWidthFraction,
                      child: const Center(child: PregoSkeletonBar(height: 16)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: lines.meta,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: PregoSkeletonBar(height: 12, width: detailsWidth),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The row's insets, shared with the launching row and the placeholder: the
/// harness logo leads [PregoSpacing.lg] in, and the time keeps the toolbar's
/// [PregoSpacing.xl] from the trailing edge.
EdgeInsetsDirectional _rowPadding({required bool pointer}) {
  final vertical = _rowVerticalPadding(pointer: pointer);
  if (pointer) return EdgeInsetsDirectional.symmetric(horizontal: PregoSpacing.md, vertical: vertical);
  return EdgeInsetsDirectional.fromSTEB(PregoSpacing.lg, vertical, PregoSpacing.xl, vertical);
}

/// A pointer row is inset from the panel, so its hover and selection read as
/// one rounded shape.
const EdgeInsets _pointerRowMargin = EdgeInsets.symmetric(horizontal: 6, vertical: 1);
const double _pointerRowRadius = PregoRadius.sm;

/// A hover action's height: the 16 pt meta line and a little of the row's inset.
const double _hoverActionHeight = 20;

/// A finger needs a roomier row than a mouse does.
double _rowVerticalPadding({required bool pointer}) => pointer ? PregoSpacing.sm : PregoSpacing.lg;

/// A title with the status mark right after its text. A long title fades out
/// before the mark, so the mark always shows; without one the title takes the
/// whole line.
class const _TitleLine({required final Widget title, required final Widget? mark}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mark = this.mark;
    return Row(
      spacing: PregoSpacing.xs,
      children: [
        Flexible(child: title),
        if (mark != null)
          SizedBox.square(
            dimension: _markSize,
            child: Center(child: mark),
          ),
      ],
    );
  }
}

/// How a row's harness logo shows.
enum _LogoTone() {
  /// A quiet grey glyph that names the harness without competing with a status.
  muted,

  /// Its own colours, holding still: the session has unread activity or is the
  /// open one.
  colored,

  /// Its own colours, breathing: an agent works.
  live,
}

/// The harness mark, leading the title under a finger and ending the meta line
/// under a pointer. Shared by the session row and the launching row so a title
/// never moves when one becomes the other.
///
/// A change of [tone] cross-fades between grey and colour, and the breath eases
/// in and out, so the logo never snaps; under reduced motion it changes at once.
/// Only the paint changes, never the size.
class const _HarnessLogo({required final String pluginId, required final _LogoTone tone}) extends StatelessWidget {
  static const _toneDuration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    return PregoBreathing(
      active: tone == _LogoTone.live,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: tone == _LogoTone.muted ? 0 : 1),
        duration: prefersReducedMotion(context) ? Duration.zero : _toneDuration,
        curve: Curves.easeInOut,
        builder: (context, colour, _) => Opacity(
          opacity: 0.7 + 0.3 * colour,
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix([
              for (final (index, grey) in _grayscale.indexed) grey + (_identity[index] - grey) * colour,
            ]),
            child: PregoBrandLogo(
              pluginId: pluginId,
              size: pointer ? _pointerBrandLogoSize : _brandLogoSize,
              // Only an unknown harness's plug takes this colour.
              color: Color.lerp(colors.textTertiary, colors.textPrimary, colour),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pointer row and its actions menu, which knows when the menu is open.
class const _PointerRowMenu({
  required final double menuWidth,
  required final List<PregoMenuEntry> Function() entriesBuilder,
  required final Widget Function(BuildContext context, VoidCallback openMenu, bool revealed, bool menuOpen) rowBuilder,
}) extends StatefulWidget {
  @override
  State<_PointerRowMenu> createState() => _PointerRowMenuState();
}

class _PointerRowMenuState() extends State<_PointerRowMenu> {
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) => PregoAnchorMenu(
    flat: true,
    menuWidth: widget.menuWidth,
    entriesBuilder: widget.entriesBuilder,
    onOpenChanged: (open) {
      if (mounted) setState(() => _menuOpen = open);
    },
    triggerBuilder: (context, openMenu) => _PointerReveal(
      builder: (context, revealed) => widget.rowBuilder(context, openMenu, revealed, _menuOpen),
    ),
  );
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

/// The row's line boxes, from the type it renders: a 16/24 title over a 12/18
/// meta line with 20px minimum height under a finger, and a 13.5/19 title over
/// a 12/16 meta line under a pointer.
double _titleLineHeightOf({required bool pointer}) => pointer ? 19 : 24;
double _metaLineHeightOf({required bool pointer}) => pointer ? 16 : 20;
const double _lineGap = PregoSpacing.xxs;

/// A quiet row's line boxes at the current text size, as its text lays them
/// out: the title's line, and the meta line's, which keeps its minimum.
({double title, double meta}) _lineHeightsOf({required BuildContext context, required bool pointer}) => (
  title: context.lineHeightOf(context.prego.textTheme.textMd.regular),
  meta: max(
    _metaLineHeightOf(pointer: pointer),
    context.lineHeightOf(_metaStyleOf(context: context, pointer: pointer)),
  ),
);

/// The meta line's type: the scale's smallest text, and under a pointer half a
/// point larger on the same 16 pt line box, to sit under the 13.5 pt title.
/// The desktop scale has no 12 pt step, and only this line needs one.
TextStyle _metaStyleOf({required BuildContext context, required bool pointer}) {
  final style = context.prego.textTheme.textXs.regular;
  if (!pointer) return style;
  return style.copyWith(
    fontSize: _pointerMetaFontSize,
    height: _metaLineHeightOf(pointer: true) / _pointerMetaFontSize,
  );
}

const double _pointerMetaFontSize = 12;

/// Rec. 709 luminance, so every harness mark reads as one quiet glyph.
const List<double> _grayscale = [
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

/// Leaves every colour as it is; the logo's colour fades from [_grayscale] to it.
const List<double> _identity = [
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

const double _markSize = 16;
const double _titleFadeWidth = 18;

/// Fits the widest relative time, "59m" at 12 pt (26 px), past its 4 px start
/// padding. A date is wider and widens its own row's column.
const double _pointerTimeWidth = 31;
const double _waitingDotSize = 8;

/// As large as the status marks, so the logo and the mark read as glyphs of
/// one size around the title.
const double _brandLogoSize = 16;

/// Under a pointer the logo sits on the meta line, inside its 16 pt line box.
const double _pointerBrandLogoSize = 14;

/// The background tasks' glyph, a little under the meta line's type.
const double _backgroundTasksGlyphSize = 12;

/// Between the meta line's details; a glyph, not words, so it is not translated.
const String _separator = " · ";

/// [title] fading off its end, only when it does not fit: a gradient on every row
/// would dim the last letter of a title that just fits. The paragraph's own fade is
/// only an ellipsis wide, which reads as a clipped word.
class const _FadingTitle({required final Text title}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: title.data, style: DefaultTextStyle.of(context).style.merge(title.style)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final overflows = painter.width > constraints.maxWidth;
      painter.dispose();
      if (!overflows) return title;
      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: const [Colors.white, Colors.white, Color(0x66FFFFFF), Colors.transparent],
          stops: [
            0,
            1 - min(1, _titleFadeWidth / bounds.width),
            1 - min(1, _titleFadeWidth * 0.45 / bounds.width),
            1 - min(1, 2 / bounds.width),
          ],
        ).createShader(bounds, textDirection: Directionality.of(context)),
        child: SizedBox(width: double.infinity, child: title),
      );
    },
  );
}
