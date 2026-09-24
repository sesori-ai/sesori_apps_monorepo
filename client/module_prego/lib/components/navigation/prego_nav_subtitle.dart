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
  error,
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
class const PregoNavSubtitle({
  super.key,

  /// The row's text, in `text-xs / medium / text-tertiary`, on one line.
  required final String text,

  /// Optional icon rendered before the [text], sized to the row's `text-xs`
  /// glyphs.
  final IconData? icon,

  /// Status dot before the row; absent when `null`.
  final PregoNavStatus? status,
}) extends StatelessWidget {
  /// Status dot diameter — the Figma online-indicator size.
  static const double _dotSize = 6;

  /// Icon size, matching the row's `text-xs` glyph height.
  static const double _iconSize = 12;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final status = this.status;
    final icon = this.icon;

    // Screen readers already get the whole text from the label itself.
    return Tooltip(
      message: text,
      excludeFromSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: PregoSpacing.xs,
        children: [
          if (status != null)
            // Decorative for screen readers (a bare box has no semantics):
            // connection changes are announced by the scaffold's banner live
            // region, so the dot never needs to speak for itself.
            Container(
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: switch (status) {
                  PregoNavStatus.online => prego.colors.fgSuccessSecondary,
                  PregoNavStatus.offline => prego.colors.fgDisabledSubtle,
                  PregoNavStatus.error => prego.colors.fgErrorPrimary,
                },
              ),
            ),
          if (icon != null) Icon(icon, size: _iconSize, color: prego.colors.textTertiary),
          Flexible(
            child: PregoEllipsisText(
              text: text,
              style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textTertiary),
              ellipsis: PregoEllipsis.middle,
            ),
          ),
        ],
      ),
    );
  }
}

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
