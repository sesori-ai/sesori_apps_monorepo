import "dart:math" as math;

import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";

import "../../module_prego.dart";

/// A page scaffold with a glass top navigation bar and the iOS-style
/// large-title collapse from the `liquid_glass_widgets` navigation showcase
/// (its `_LargeTitleCollapseDemo`).
///
/// Built on the package's [GlassScaffold] with its bar provided by
/// [PregoTopNavigation]: the bar surface is transparent and glass is reserved
/// for the buttons ([PregoButtonsIconGlass]), and the body scrolls behind the
/// bar. As content approaches the bar it both dissolves into the [GlassScaffold]
/// colour fade and softens under a graduated [PregoScrollEdgeBlur], frosting the
/// content behind the transparent bar and releasing it smoothly just below —
/// the iOS-26 scroll-edge look. A large [title] sits below the bar; as the body
/// scrolls it fades out while the same title fades in, centred, inside the bar.
///
/// This scaffold owns the whole page around the bar. The collapse couples the
/// bar title's opacity to the body's scroll offset, so the scaffold owns the
/// [ScrollController] — shared with [PregoTopNavigation] through
/// [PregoTopNavigation.collapseProgressOf] — and hosts the body's [slivers] in
/// its own [CustomScrollView]. Callers pass only their content slivers — the
/// leading spacer and the large-title sliver are added here.
///
/// The bar's [leading]/[onBack]/[automaticallyImplyLeading], [actions], and
/// [title]/[subtitle] are forwarded to [PregoTopNavigation]; see it for how the
/// leading back button is resolved.
///
/// Set [extendBodyBehindBar] to `false` for bodies with pinned slivers (e.g. a
/// sticky-header list): those must pin directly below the bar, which is
/// incompatible with a body scrolling behind a transparent bar. With it off,
/// [GlassScaffold] insets the body below the bar instead.
///
/// Set [inlineTitle] to `true` for a fixed, centred title (and [subtitle]) in
/// the bar — the showcase's inline-title pattern (`_InlineTitleDemo`) — instead
/// of the large title that collapses on scroll. Use it for screens whose body
/// owns its own scroll (e.g. a chat with a reversed controller), where a
/// collapsing large title has nothing to collapse against.
///
/// Usage:
/// ```dart
/// PregoGlassScaffold(
///   title: loc.projectListTitle,
///   actions: [PregoGlassBarButton(icon: VESPRSolid.gear, onPressed: openSettings)],
///   onRefresh: cubit.refresh,
///   slivers: [SliverList.builder(...)],
/// )
/// ```
class PregoGlassScaffold extends StatefulWidget {
  const PregoGlassScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.subtitle,
    this.inlineTitle = false,
    this.actions,
    this.leading,
    this.onBack,
    this.automaticallyImplyLeading = true,
    this.floatingActionButton,
    this.overlay,
    this.onRefresh,
    this.backgroundColor,
    this.extendBodyBehindBar = true,
  });

  /// Primary title — shown large below the bar and, once collapsed, inline.
  final String title;

  /// Optional second line rendered beneath the [title] in a muted style.
  final String? subtitle;

  /// When `true`, the bar shows a fixed, centred [title] (and [subtitle]) inline
  /// instead of the large title that collapses on scroll. See the class doc.
  final bool inlineTitle;

  /// The page's content slivers, rendered below the auto-injected spacer and
  /// large title. Non-scrolling states (loading, empty, error) should be a
  /// single [SliverFillRemaining].
  final List<Widget> slivers;

  /// Trailing bar actions. Build these with PregoButtonsIconGlass components so
  /// they match the leading/back button.
  final List<Widget>? actions;

  /// Overrides the leading slot entirely. Takes precedence over [onBack] and
  /// [automaticallyImplyLeading].
  final Widget? leading;

  /// When set (and [leading] is null), renders a glass back button that invokes
  /// this callback instead of relying on the enclosing navigator.
  final VoidCallback? onBack;

  /// Whether the bar may infer a back button from the navigator when neither
  /// [leading] nor [onBack] is supplied.
  final bool automaticallyImplyLeading;

  /// Optional floating action button, forwarded to the inner [GlassScaffold].
  final Widget? floatingActionButton;

  /// A full-screen overlay painted above the body but below the bar, so the
  /// bar (and its back button) stays interactive while it is shown. Use for a
  /// modal scrim such as a blocking loading indicator. Null shows nothing.
  final Widget? overlay;

  /// When set, the scroll view is wrapped in a [RefreshIndicator].
  final Future<void> Function()? onRefresh;

  /// Page background painted behind the glass. Defaults to `bg-primary`.
  final Color? backgroundColor;

  /// Whether the body scrolls behind the bar. Defaults to `true`. Set `false`
  /// for bodies with pinned slivers that must pin below the bar.
  final bool extendBodyBehindBar;

  @override
  State<PregoGlassScaffold> createState() => _PregoGlassScaffoldState();
}

class _PregoGlassScaffoldState extends State<PregoGlassScaffold> {
  final ScrollController _scrollController = ScrollController();

  /// How far past the bar the scroll-edge effects (the package colour fade and
  /// the [PregoScrollEdgeBlur]) ramp out. A little longer than the package
  /// default (20) for a softer, smoother release of content below the bar.
  static const double _scrollEdgeFadeExtent = 80;

  /// Page glass-layer settings replicated from the showcase's
  /// `RecommendedGlassSettings.standard` (an example-only constant, not a
  /// package export).
  static const LiquidGlassSettings _pageSettings = LiquidGlassSettings(
    blur: 4,
    thickness: 10,
    glassColor: Color.fromRGBO(255, 255, 255, 0.08),
    lightAngle: 0.75 * math.pi,
    lightIntensity: 0.7,
    ambientStrength: 0,
    saturation: 1.2,
    refractiveIndex: 1.2,
    chromaticAberration: 0.01,
    specularSharpness: GlassSpecularSharpness.medium,
  );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 0 while the large title is fully shown, 1 once it has collapsed into the
  /// bar. Delegates to [PregoTopNavigation.collapseProgressOf] — the single
  /// source of truth for the collapse — so the large-title sliver fades out in
  /// lockstep with the bar title fading in.
  double get _collapseProgress => PregoTopNavigation.collapseProgressOf(_scrollController);

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final extendBehind = widget.extendBodyBehindBar;
    final inline = widget.inlineTitle;

    // The bar. It shares this scaffold's [_scrollController] so its collapsing
    // title fades in as the large-title sliver below scrolls away.
    final topNav = PregoTopNavigation(
      title: widget.title,
      subtitle: widget.subtitle,
      inlineTitle: inline,
      scrollController: _scrollController,
      actions: widget.actions,
      leading: widget.leading,
      onBack: widget.onBack,
      automaticallyImplyLeading: widget.automaticallyImplyLeading,
    );

    Widget scrollView = CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // When the body scrolls behind the bar, reserve space so the title
        // clears it. When it doesn't, GlassScaffold already insets the body
        // below the bar, so a spacer would double the gap.
        if (extendBehind) SliverToBoxAdapter(child: SizedBox(height: topPad + topNav.preferredSize.height)),
        // Inline mode shows a fixed title in the bar, so there is no large
        // title sliver to scroll away.
        if (!inline) _buildLargeTitleSliver(),
        ...widget.slivers,
      ],
    );

    final onRefresh = widget.onRefresh;
    if (onRefresh != null) {
      scrollView = RefreshIndicator(onRefresh: onRefresh, child: scrollView);
    }

    final overlay = widget.overlay;

    // Overlays painted above the body but below the bar in GlassScaffold's
    // z-order stack. Order matters — later entries paint on top:
    //  1. the scroll-edge blur (frosts content passing behind the bar), then
    //  2. the optional modal scrim (dims everything, including the blur).
    // Both sit below the bar so its glass buttons stay interactive.
    final bodyOverlays = <Widget>[
      // Only fade when the body actually scrolls behind the bar; with
      // [extendBehind] off, GlassScaffold insets the body below the bar so
      // there is nothing behind it to fade. Wrapped in [IgnorePointer] so the
      // decorative gradient never swallows taps or scroll drags starting in the
      // top region — content beneath it stays fully interactive.
      if (extendBehind)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.prego.colors.bgPrimary.withValues(alpha: 0.9),
                    context.prego.colors.bgPrimary.withValues(alpha: 0.7),
                    context.prego.colors.bgPrimary.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.8, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              // Extend past the bar by the scroll-edge fade extent so the
              // gradient releases in lockstep with the package colour fade
              // ([topEdgeFadeExtent]) instead of stopping at the bar edge.
              height: topPad + topNav.preferredSize.height + _scrollEdgeFadeExtent,
            ),
          ),
        ),
      if (overlay != null) Positioned.fill(child: overlay),
    ];

    return GlassScaffold(
      backgroundColor: widget.backgroundColor ?? context.prego.colors.bgPrimary,
      settings: _pageSettings,
      statusBarStyle: GlassStatusBarStyle.auto,
      extendBody: extendBehind,
      // Extend the package's colour fade past the bar by the same amount the
      // blur ramps out over, so the two scroll-edge effects share one boundary.
      topEdgeFadeExtent: _scrollEdgeFadeExtent,
      floatingActionButton: widget.floatingActionButton,
      bodyOverlays: bodyOverlays.isEmpty ? null : bodyOverlays,
      appBar: topNav,
      body: scrollView,
    );
  }

  /// The large title below the bar — scrolls away with the body and fades out
  /// as it collapses into the bar.
  Widget _buildLargeTitleSliver() {
    final subtitle = widget.subtitle;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(PregoSpacing.x3l, 0, PregoSpacing.x3l, PregoSpacing.xl),
        child: ListenableBuilder(
          listenable: _scrollController,
          builder: (context, _) {
            final prego = context.prego;
            return Opacity(
              opacity: (1 - _collapseProgress).clamp(0.0, 1.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: prego.textTheme.displayMd.medium.copyWith(color: prego.colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
