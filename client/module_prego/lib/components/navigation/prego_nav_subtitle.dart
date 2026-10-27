import "package:material_ui/material_ui.dart";

import "../../module_prego.dart";

/// The connection state the [PregoNavSubtitle] status dot reports.
enum PregoNavStatus() {
  /// Connected — a green dot.
  online,

  /// Not connected, and that is unremarkable — a muted grey dot.
  offline,

  /// Not connected, and the page is about that — a red dot. Used by the
  /// bridge onboarding, where waiting for a connection *is* the screen.
  error;

  /// The status dot's colour, wherever a dot reports this status.
  Color dotColor({required PregoColors colors}) => switch (this) {
    PregoNavStatus.online => colors.fgSuccessSecondary,
    PregoNavStatus.offline => colors.fgDisabledSubtle,
    PregoNavStatus.error => colors.fgErrorPrimary,
  };
}

/// The small round dot that reports a [PregoNavStatus] beside text.
///
/// Decorative for screen readers (a bare box has no semantics): every row it
/// leads already says the status in words, or has it announced elsewhere.
class const _StatusDot({required final PregoNavStatus status}) extends StatelessWidget {
  /// The Figma online-indicator size.
  static const double _size = 6;

  @override
  Widget build(BuildContext context) => Container(
    width: _size,
    height: _size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: status.dotColor(colors: context.prego.colors),
    ),
  );
}

/// A status in words ("Online") led by the dot [PregoNavSubtitle] shows for
/// it, so a list row can say at a glance what its text spells out. The dot
/// sits centred on the text's first line, however the text wraps.
class const PregoStatusLabel({
  super.key,
  required final PregoNavStatus status,
  required final String text,

  /// Applied over the ambient [DefaultTextStyle]; null keeps it as it is.
  required final TextStyle? style,

  /// Caps the text at this many lines, ending in an ellipsis; null lets it
  /// wrap.
  required final int? maxLines,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Measured rather than computed, so a style without a height still works.
    final line = TextPainter(
      text: TextSpan(style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final lineHeight = line.preferredLineHeight;
    line.dispose();
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: PregoSpacing.xs,
      children: [
        // As tall as the first line, so the dot centres on it.
        SizedBox(
          height: lineHeight,
          child: Center(child: _StatusDot(status: status)),
        ),
        Flexible(
          child: Text(
            text,
            style: style,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// The contextual subtitle row of the top navigation bar's back-leading title
/// block ([PregoNavLeadingTitle]), as instantiated on the sessions list
/// (Figma node 2386:11558) and the Projects page (node 2459:26970): an
/// optional [status] dot, an optional leading [icon] and the [text]. A text too
/// long for the bar shortens in the middle, and a long press or hover shows it
/// whole.
///
/// The row is self-contained — callers compose it (icon, dot) and
/// hand the finished widget to [PregoGlassScaffold.subtitle] /
/// [PregoTopNavigation.subtitle] instead of threading row parts through the
/// bar's API.
///
/// With an [action] the row is a control: a trailing chevron says it opens
/// something (the Projects page's computer menu), and the whole row is the tap
/// target.
class const PregoNavSubtitle({
  super.key,

  /// The row's text, in `text-xs / medium / text-tertiary`, on one line.
  required final String text,

  /// Optional icon rendered before the [text], sized to the row's `text-xs`
  /// glyphs.
  final IconData? icon,

  /// Status dot before the row; absent when `null`.
  final PregoNavStatus? status,

  /// Makes the row a button with a trailing chevron; a plain label when `null`.
  final PregoNavSubtitleAction? action,
}) extends StatelessWidget {
  /// Icon size, matching the row's `text-xs` glyph height.
  static const double _iconSize = 12;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final status = this.status;
    final icon = this.icon;
    final action = this.action;

    // Screen readers already get the whole text from the label itself.
    final row = Tooltip(
      message: text,
      excludeFromSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: PregoSpacing.xs,
        children: [
          // Connection changes are announced by the scaffold's banner live
          // region, so the silent dot never needs to speak for itself.
          if (status != null) _StatusDot(status: status),
          if (icon != null) Icon(icon, size: _iconSize, color: prego.colors.textTertiary),
          Flexible(
            child: PregoEllipsisText(
              text: text,
              style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textTertiary),
              ellipsis: PregoEllipsis.middle,
            ),
          ),
          if (action != null) Icon(TablerRegular.chevron_down, size: _iconSize, color: prego.colors.textTertiary),
        ],
      ),
    );
    if (action == null) return row;
    // Its own node, so the button never merges with the title above it.
    return Semantics(
      container: true,
      button: true,
      hint: action.semanticsHint,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: action.onTap, child: row),
    );
  }
}

/// What a tappable [PregoNavSubtitle] does, and how a screen reader describes
/// it beyond the row's own text.
class const PregoNavSubtitleAction({required final VoidCallback onTap, required final String semanticsHint});

/// The subtitle slot's loading placeholder: a single shimmering skeleton pill
/// standing in for a [PregoNavSubtitle] whose data is still being fetched
/// (e.g. the sessions bar before the project's repository identity arrives).
///
/// The pill sits in the same `text-xs` line box the real row occupies, so the
/// title block keeps its height when data replaces the skeleton. It wraps its
/// own [PregoShimmer] — the bar lives outside the page body, so it cannot
/// join a body skeleton's sweep region — and inherits the shimmer's anti-flash
/// appear delay, keeping fast loads from blinking a placeholder. Like all
/// skeletons it is decorative: [PregoShimmer] excludes it from semantics.
class const PregoNavSubtitleSkeleton({super.key}) extends StatelessWidget {
  /// The real row's height: the `text-xs` line box (12px glyphs, 18px line).
  static const double _rowHeight = 18;

  /// A 12px pill centred in the line box, wide enough to read as a typical
  /// `owner/repo` slug.
  static const double _barHeight = 12;
  static const double _barWidth = 120;

  @override
  Widget build(BuildContext context) {
    return const PregoShimmer(
      child: SizedBox(
        width: _barWidth,
        height: _rowHeight,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: PregoSkeletonBar(height: _barHeight, width: _barWidth),
        ),
      ),
    );
  }
}
