import "package:flutter/material.dart";

import "../../module_prego.dart";
import "../../utils/color_extensions.dart";

/// A modal bottom sheet with the app's glass navigation header
/// ([PregoTopNavigationSheets]) over a solid rounded-top surface.
///
/// It sizes to its [child]: short content sits part-way up the screen; tall
/// content grows until it meets the status bar and then scrolls. The body
/// scrolls *behind* the transparent glass header, dissolving into a scroll-edge
/// gradient just below the bar — the same treatment [PregoGlassScaffold] gives a
/// full page. Drag the header/grabber down to dismiss.
///
/// Prefer [showPregoBottomSheet], which presents this widget as a modal route
/// and wires the close button to pop it. Using [PregoBottomSheet] directly is
/// supported, but then the caller owns dismissal: supply [onClose] (or [onBack])
/// so the sheet has an in-sheet dismiss affordance for screen-reader users.
///
/// Usage:
/// ```dart
/// showPregoBottomSheet(
///   context: context,
///   title: loc.whyTitle,
///   builder: (_) => const WhyContent(),
/// );
/// ```
class PregoBottomSheet extends StatelessWidget {
  const PregoBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.alignment = PregoSheetTitleAlignment.center,
    this.onClose,
    this.onBack,
    this.actions,
    this.leading,
    this.surfaceColor,
    this.contentPadding = const EdgeInsetsDirectional.symmetric(horizontal: PregoSpacing.xl),
    this.handleBottomSafeArea = true,
    this.topInset,
  });

  /// Header title. See [PregoTopNavigationSheets.title].
  final String title;

  /// Optional header subtitle. See [PregoTopNavigationSheets.subtitle].
  final String? subtitle;

  /// The sheet body. It is padded down to clear the header and scrolls behind
  /// it; wrap tall content in a single widget (e.g. a [Column]).
  final Widget child;

  /// Header title alignment. Defaults to [PregoSheetTitleAlignment.center].
  final PregoSheetTitleAlignment alignment;

  /// Invoked by the header's close button. [showPregoBottomSheet] injects a
  /// route-pop; pass your own when using this widget directly.
  final VoidCallback? onClose;

  /// When set, the header's leading slot is a back button invoking this — for
  /// in-sheet navigation. It sits alongside the trailing close button rather
  /// than replacing it.
  final VoidCallback? onBack;

  /// Trailing header actions. See [PregoTopNavigationSheets.actions].
  final List<Widget>? actions;

  /// Overrides the header's leading slot entirely.
  final Widget? leading;

  /// The sheet surface colour (also the scroll-edge fade colour). Defaults to
  /// `bg-secondary` — a raised surface that flips correctly in dark mode.
  final Color? surfaceColor;

  /// Padding applied around [child] (not the header). Defaults to 16pt
  /// horizontal.
  final EdgeInsetsGeometry contentPadding;

  /// Whether to pad the body up by the bottom safe area (home indicator) when
  /// the keyboard is hidden. Set `false` for content that scrolls to the very
  /// bottom edge. The keyboard inset is always applied.
  final bool handleBottomSafeArea;

  /// The top inset (status bar / notch) the sheet keeps clear when it grows to
  /// full height.
  ///
  /// [showPregoBottomSheet] supplies the real inset captured from the presenting
  /// context, because the modal route strips the top padding from the sheet's
  /// own [MediaQuery] (`showModalBottomSheet` wraps `useSafeArea: false` content
  /// in `MediaQuery.removePadding(removeTop: true)`). When null — e.g. a direct
  /// caller not behind that wrapper — the sheet falls back to
  /// [MediaQuery.paddingOf].
  final double? topInset;

  /// Extra height, below the header, over which the scroll-edge gradient fades
  /// content out.
  static const double _fadeExtent = PregoSpacing.x3l;

  /// Height of the sheet chrome above the body: the glass header plus the
  /// scroll-edge fade below it.
  ///
  /// A body that hosts its own scroll view needs a bounded height; subtract
  /// this (and the top inset the sheet keeps clear) from the screen height so
  /// the sheet tops out exactly at its cap instead of spilling into the outer
  /// scroll.
  static const double contentTopInset = PregoTopNavigationSheets.headerHeight + _fadeExtent;

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    // The modal strips the top padding from the sheet's own MediaQuery, so use
    // the inset [showPregoBottomSheet] captured from the presenting context;
    // only fall back to MediaQuery for a direct caller (see [topInset]).
    final topInset = this.topInset ?? MediaQuery.paddingOf(context).top;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final surface = surfaceColor ?? colors.bgSecondary;

    // Cap the sheet just below the status bar. Size is unaffected by the modal's
    // padding removal, so subtracting the real [topInset] stops a full-height
    // sheet from sliding its header under the status bar / notch.
    final maxHeight = MediaQuery.heightOf(context) - topInset;

    // Push the body above the keyboard when it is up, otherwise clear the home
    // indicator — but never both at once. Mirrors the app's _ModalSafeArea.
    final bottomInset = keyboard > 0 ? keyboard : (handleBottomSafeArea ? bottomSafe : 0.0);

    return Container(
      // A real clipper (not DecoratedBox) so the rounded top corners clip the
      // scroll-edge gradient and any content scrolling behind the header.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(PregoRadius.x8l),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Stack(
          children: [
            // (1) The body — the sole non-positioned child, so the Stack (and
            // thus the sheet) sizes to it: it wraps its content when short and
            // caps at [maxHeight], scrolling, when tall.
            CustomScrollView(
              shrinkWrap: true,
              slivers: [
                // Clear the header plus the fade below it, so resting content
                // starts fully legible and only dissolves once it scrolls up
                // under the bar.
                const SliverToBoxAdapter(
                  child: SizedBox(height: contentTopInset),
                ),
                SliverToBoxAdapter(
                  child: Padding(padding: contentPadding, child: child),
                ),
                SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
              ],
            ),

            // (2) Scroll-edge fade: content dissolves into the surface just
            // below the bar. Same-hue (surface -> alpha 0), not Colors
            // .transparent, so it never fades through a muddy tint. Mirrors
            // PregoGlassScaffold's custom gradient (its bar owns the fade, not
            // the package edge effect).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: contentTopInset,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.75, 1.0],
                      colors: [
                        surface.withMultipliedOpacity(1),
                        surface.withMultipliedOpacity(0.9),
                        surface.withMultipliedOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // (3) The glass header, pinned on top. The opaque hit-test barrier
            // stops header/grabber drags from falling through to the scroll
            // view behind it (which would overscroll instead of dismissing), so
            // those drags reach the modal's own drag-to-dismiss recognizer. The
            // glass buttons are descendants and still receive their taps.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                child: PregoTopNavigationSheets(
                  title: title,
                  subtitle: subtitle,
                  alignment: alignment,
                  onClose: onClose,
                  onBack: onBack,
                  actions: actions,
                  leading: leading,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Presents a [PregoBottomSheet] as a modal route and returns the value it is
/// popped with.
///
/// The sheet is scroll-controlled (so it can grow to the status bar) over a
/// transparent route background — [PregoBottomSheet] paints its own rounded
/// surface. Scrim-tap and drag-to-dismiss both follow [isDismissible]. The
/// close button pops this route.
// ignore: no_slop_linter/prefer_required_named_parameters, contentPadding/handleBottomSafeArea keep sheet-chrome defaults
Future<T?> showPregoBottomSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  String? subtitle,
  PregoSheetTitleAlignment alignment = PregoSheetTitleAlignment.center,
  List<Widget>? actions,
  VoidCallback? onBack,
  Widget? leading,
  Color? surfaceColor,
  EdgeInsetsGeometry contentPadding = const EdgeInsetsDirectional.symmetric(
    horizontal: PregoSpacing.xl,
  ),
  bool handleBottomSafeArea = true,
  bool isDismissible = true,
}) {
  // Capture the real status-bar inset here, from the presenting context: the
  // modal route strips the top padding from the sheet's own MediaQuery, so the
  // sheet can't read it once inside.
  final topInset = MediaQuery.paddingOf(context).top;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    // PregoBottomSheet paints the rounded surface; keep the route transparent.
    backgroundColor: Colors.transparent,
    // The sheet caps itself just below the status bar, so no route SafeArea.
    useSafeArea: false,
    isDismissible: isDismissible,
    // Keep swipe-down consistent with the scrim: a non-dismissible sheet must
    // not be drag-dismissable either (enableDrag defaults to true otherwise).
    enableDrag: isDismissible,
    builder: (sheetContext) => PregoBottomSheet(
      title: title,
      subtitle: subtitle,
      alignment: alignment,
      actions: actions,
      onBack: onBack,
      leading: leading,
      surfaceColor: surfaceColor,
      contentPadding: contentPadding,
      handleBottomSafeArea: handleBottomSafeArea,
      topInset: topInset,
      // Pops the modal route this helper pushed (always dismissible). This
      // design module has no go_router dependency, so it pops the sheet's own
      // Navigator route directly.
      // ignore: no_slop_linter/avoid_navigator_of, design module has no go_router dep; pops the modal route this helper pushed
      onClose: () => Navigator.of(sheetContext).pop(),
      child: builder(sheetContext),
    ),
  );
}
