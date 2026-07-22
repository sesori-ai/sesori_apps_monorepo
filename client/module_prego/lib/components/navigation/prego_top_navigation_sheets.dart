import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";

import "../../module_prego.dart";

/// How the [PregoTopNavigationSheets] title (and subtitle) are aligned across the
/// bar: [center] mirrors [PregoTopNavigation]'s centred title, [start] pins the
/// block to the leading edge (the Figma "Title 2 Line Left" style).
enum PregoSheetTitleAlignment { center, start }

/// The header of [PregoBottomSheet] — the Figma `pregoTopNavigationSheets`
/// component: a drag [showGrabber] pill above a fixed nav row with an optional
/// leading back button, a centred-or-leading title (+ optional [subtitle]), and
/// trailing [actions] plus the close button.
///
/// It is the sheet counterpart to [PregoTopNavigation]: same transparent bar
/// with glass buttons ([PregoButtonsIconGlass]), but with a drag grabber instead
/// of a large collapsing title. It is a fixed, self-contained header — it never
/// collapses on scroll — so a sheet body can scroll behind it (see
/// [PregoBottomSheet]).
///
/// The close button ([TablerRegular.x], wired to [onClose]) sits on the trailing
/// edge, after [actions]. In-sheet navigation ([onBack]) adds a leading back
/// arrow ([TablerRegular.arrow_left]) beside it: the two answer different
/// questions — back steps within the sheet, close leaves it — so a sheet that
/// navigates keeps both, as the Figma browser states do.
///
/// Leading resolution (first match wins):
/// 1. an explicit [leading] widget;
/// 2. a glass back button wired to [onBack], for in-sheet navigation.
///
/// The back/close affordances announce the platform's standard
/// back/close tooltips so screen readers describe them without a bespoke string.
class PregoTopNavigationSheets extends StatelessWidget implements PreferredSizeWidget {
  const PregoTopNavigationSheets({
    super.key,
    required this.title,
    this.subtitle,
    this.alignment = PregoSheetTitleAlignment.center,
    this.showGrabber = true,
    this.onClose,
    this.onBack,
    this.actions,
    this.leading,
  });

  /// Primary title — `text-lg / bold / text-primary`.
  final String title;

  /// Optional second line in `text-md / regular / text-secondary`. A `null` or
  /// empty value renders the title on its own.
  final String? subtitle;

  /// Whether the title block is centred across the bar or pinned to the leading
  /// edge. Defaults to [PregoSheetTitleAlignment.center].
  final PregoSheetTitleAlignment alignment;

  /// Whether to render the drag grabber pill above the nav row. Defaults to
  /// `true`. The grabber is decorative — dragging it dismisses the sheet, but
  /// the affordance is owned by the enclosing modal, not this widget.
  final bool showGrabber;

  /// Renders a glass close button (`x`) on the trailing edge that invokes this
  /// callback. It lives in the trailing slot, so neither [leading] nor [onBack]
  /// suppresses it.
  final VoidCallback? onClose;

  /// Renders a glass back button (`arrow-left`) in the leading slot that invokes
  /// this callback, for stepping back within the sheet.
  final VoidCallback? onBack;

  /// Trailing bar actions. Build these with [PregoButtonsIconGlass] so they
  /// match the leading button.
  final List<Widget>? actions;

  /// Overrides the leading slot entirely. Takes precedence over [onBack]'s back
  /// arrow. It governs only the leading slot, so it leaves the trailing
  /// [onClose] button untouched.
  final Widget? leading;

  /// Height of the drag-grabber block above the nav row.
  static const double grabberBlockHeight = 16;

  /// Height of the nav (controls) row — matches the glass button diameter.
  static const double controlsRowHeight = 44;

  /// Total header height, exposed so [PregoBottomSheet] can reserve the space
  /// its body must scroll behind.
  static const double headerHeight = grabberBlockHeight + controlsRowHeight;

  static const double _grabberWidth = 36;
  static const double _grabberHeight = 5;

  /// Line-height multiplier for the title/subtitle, overriding the body-text
  /// leading so a two-line title+subtitle stack fits the fixed
  /// [controlsRowHeight] on every platform (mirrors [PregoNavTitle]'s rationale
  /// for the taller top bar).
  static const double _titleLineHeight = 1.2;

  @override
  Size get preferredSize => Size.fromHeight(showGrabber ? headerHeight : controlsRowHeight);

  @override
  Widget build(BuildContext context) {
    final leading = _resolveLeading(context);
    final trailing = _resolveTrailing(context);
    final isCenter = alignment == PregoSheetTitleAlignment.center;

    // Same layout PregoTopNavigation uses: hand NavigationToolbar a single
    // full-width row so the centred title is centred across the whole bar (not
    // just the gap between side widgets), and shifted only if it would overlap.
    final controls = SizedBox(
      height: controlsRowHeight,
      child: NavigationToolbar(
        centerMiddle: isCenter,
        // NavigationToolbar stretches its leading slot full-height and
        // top-aligns it, which would squash the circular glass button; wrap in
        // an [Align] (widthFactor 1) to keep it its natural size, centred.
        leading: leading == null ? null : Align(widthFactor: 1, child: leading),
        middle: _SheetTitle(
          title: title,
          subtitle: subtitle,
          alignment: alignment,
          lineHeight: _titleLineHeight,
        ),
        trailing: trailing,
      ),
    );

    // Force the glass buttons to render their own layer, exactly as
    // [GlassAppBar] does. Unlike the top bar, a sheet header has no
    // enclosing [GlassScaffold]/[GlassPage] (a modal route sits outside the
    // page), so without this the buttons would have no glass layer to join.
    return GlassIsolationScope(
      isolated: true,
      child: Padding(
        // Leading/trailing buttons sit 16pt from the bar edges.
        padding: const EdgeInsetsDirectional.symmetric(horizontal: PregoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showGrabber) _buildGrabber(context),
            controls,
          ],
        ),
      ),
    );
  }

  Widget _buildGrabber(BuildContext context) {
    // Decorative: no semantics node. Drag-to-dismiss is unreachable by screen
    // readers, so the close button and the modal barrier are the announced
    // dismiss affordances.
    return SizedBox(
      height: grabberBlockHeight,
      child: Center(
        child: Container(
          width: _grabberWidth,
          height: _grabberHeight,
          decoration: BoxDecoration(
            color: context.prego.colors.textSecondary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(PregoRadius.full),
          ),
        ),
      ),
    );
  }

  /// Resolves the leading bar button. Always renders the app's glass button
  /// ([PregoButtonsIconGlass]) so the affordance matches the design on every
  /// screen, announcing the platform's standard back/close tooltip.
  Widget? _resolveLeading(BuildContext context) {
    final leading = this.leading;
    if (leading != null) return leading;

    final onBack = this.onBack;
    if (onBack != null) return _backButton(context, onBack: onBack);

    return null;
  }

  /// Resolves the trailing bar row: [actions] followed by the close button.
  /// Null when the row would be empty.
  Widget? _resolveTrailing(BuildContext context) {
    final onClose = this.onClose;
    final trailingClose = onClose != null ? _closeButton(context, onClose: onClose) : null;

    final children = [...?actions, ?trailingClose];
    if (children.isEmpty) return null;

    return Row(mainAxisSize: MainAxisSize.min, spacing: PregoSpacing.md, children: children);
  }

  Widget _backButton(BuildContext context, {required VoidCallback onBack}) {
    return PregoButtonsIconGlass(
      // A sheet steps back through its own content rather than up a navigation
      // stack, which the Figma sheet header marks with a full arrow. The page
      // bar (PregoTopNavigation) keeps the chevron.
      icon: TablerRegular.arrow_left,
      onPressed: onBack,
      semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
    );
  }

  Widget _closeButton(BuildContext context, {required VoidCallback onClose}) {
    return PregoButtonsIconGlass(
      icon: TablerRegular.x,
      onPressed: onClose,
      semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
    );
  }
}

/// The sheet header's title block, aligned per [alignment] — which selects the
/// type scale as well as the position, matching the two Figma variants:
///
/// * [PregoSheetTitleAlignment.center] — a headline over the sheet's content:
///   `text-lg / bold / text-primary` with `text-md / regular / text-secondary`
///   beneath it.
/// * [PregoSheetTitleAlignment.start] — a nav bar for content the sheet browses
///   ("Title 2 Line Left"): the quieter `text-md / medium / text-primary` over
///   `text-xs / regular / text-tertiary`, so a long second line (a path) fits
///   between the leading and trailing buttons.
///
/// Distinct from [PregoNavTitle] (which is `text-lg / medium`, centre-only,
/// tuned for the taller top bar) by this bar's tighter [lineHeight].
class _SheetTitle extends StatelessWidget {
  const _SheetTitle({
    required this.title,
    required this.subtitle,
    required this.alignment,
    required this.lineHeight,
  });

  final String title;
  final String? subtitle;
  final PregoSheetTitleAlignment alignment;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final subtitle = this.subtitle;
    final isCenter = alignment == PregoSheetTitleAlignment.center;
    final textAlign = isCenter ? TextAlign.center : TextAlign.start;
    final titleStyle = isCenter ? prego.textTheme.textLg.bold : prego.textTheme.textMd.medium;
    final subtitleStyle = isCenter ? prego.textTheme.textMd.regular : prego.textTheme.textXs.regular;
    final subtitleColor = isCenter ? prego.colors.textSecondary : prego.colors.textTertiary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: isCenter ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: titleStyle.copyWith(color: prego.colors.textPrimary, height: lineHeight),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
        ),
        if (subtitle != null && subtitle.isNotEmpty)
          Text(
            subtitle,
            style: subtitleStyle.copyWith(color: subtitleColor, height: lineHeight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
          ),
      ],
    );
  }
}
