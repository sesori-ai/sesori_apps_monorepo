import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";

import "../../module_prego.dart";
import "../../utils/color_extensions.dart";

/// A page scaffold with a glass top navigation bar and the iOS-style
/// large-title collapse from the `liquid_glass_widgets` navigation showcase
/// (its `_LargeTitleCollapseDemo`).
///
/// Built on the package's [GlassScaffold] with its bar provided by
/// [PregoTopNavigation]: the bar surface is transparent and glass is reserved
/// for the buttons ([PregoButtonsIconGlass]), and the body scrolls behind the
/// bar. As content approaches the bar it dissolves into the [GlassScaffold]
/// colour fade, releasing it smoothly just below — the iOS-26 scroll-edge look.
/// A large [title] sits below the bar; as the body
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
/// Set [reserveBarSpace] to `false` when the body owns its own scroll behind the
/// bar (e.g. a reversed chat list) and manages the bar inset itself. The
/// auto-injected top spacer is then skipped, so the body's first sliver fills
/// the full height behind the bar; the body must pad its scrollable content
/// down via [PregoTopBarInsetBuilder] so it clears the bar — and any inline
/// [banner] — at rest. Only meaningful with [extendBodyBehindBar] and, in
/// practice, [inlineTitle] (a collapsing large title has nothing to reserve
/// against here).
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
    this.banner,
    this.actions,
    this.leading,
    this.onBack,
    this.automaticallyImplyLeading = true,
    this.floatingActionButton,
    this.overlay,
    this.onRefresh,
    this.backgroundColor,
    this.extendBodyBehindBar = true,
    this.reserveBarSpace = true,
    this.scrollable = true,
  }) : assert(scrollable || onRefresh == null, "onRefresh requires scrollable to be true (RefreshIndicator needs a draggable page)");

  /// Primary title — shown large below the bar and, once collapsed, inline.
  final String title;

  /// Optional second line rendered beneath the [title] in a muted style.
  final String? subtitle;

  /// When `true`, the bar shows a fixed, centred [title] (and [subtitle]) inline
  /// instead of the large title that collapses on scroll. See the class doc.
  final bool inlineTitle;

  /// An inline alert hosted in the top-navigation area, below the status bar
  /// and above the bar row (e.g. a [PregoInlineAlertsNotifications]).
  ///
  /// Going `null` → non-null slides the alert down from under the status bar,
  /// pushing the bar row — and the body's top inset — down by its height;
  /// going non-null → `null` slides it back up and restores the layout. Both
  /// transitions are height animations ([AnimatedSize]); page content follows
  /// the actually-rendered height, so intrinsically sized content (multi-line
  /// text, large text scales) needs no manual measurement. Bodies that inset
  /// themselves (see [reserveBarSpace]) follow it via [PregoTopBarInsetBuilder].
  ///
  /// The widget must not depend on [PregoTopBarInsetBuilder] itself: the
  /// banner's rendered height feeds that inset, so reading it back from inside
  /// the banner would oscillate between the two layouts.
  final Widget? banner;

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

  /// Whether to inject the top spacer that pushes the first content below the
  /// bar. Defaults to `true`. Set `false` when the body owns its own scroll and
  /// insets itself (see the class doc).
  final bool reserveBarSpace;

  /// Whether the page itself scrolls. Defaults to `true`
  /// ([AlwaysScrollableScrollPhysics]). Set `false`
  /// ([NeverScrollableScrollPhysics]) for screens whose body fills the viewport
  /// and owns its own scroll (e.g. a reversed chat list): the outer page then
  /// can't overscroll/bounce, so a drag that starts outside the inner list —
  /// e.g. on a pinned composer — no longer drags the whole page. Only the body's
  /// own scrollable moves. Incompatible with [onRefresh], which needs the page
  /// to be draggable.
  final bool scrollable;

  @override
  State<PregoGlassScaffold> createState() => _PregoGlassScaffoldState();
}

class _PregoGlassScaffoldState extends State<PregoGlassScaffold> {
  final ScrollController _scrollController = ScrollController();

  /// The banner slot's currently rendered height, measured after each layout.
  /// While the banner animates, this follows the animation one frame behind
  /// (measure → notify → rebuild); every inset derived from the bar area — the
  /// content spacer, the scroll-edge gradient, GlassScaffold's non-extended
  /// body offset, and [PregoTopBarInsetBuilder] consumers — listens to it, so
  /// content tracks the moving bar and is exact at rest.
  final ValueNotifier<double> _bannerHeight = ValueNotifier<double>(0);

  @override
  void dispose() {
    _scrollController.dispose();
    _bannerHeight.dispose();
    super.dispose();
  }

  void _onBannerHeightChanged(double height) {
    // The measurement arrives in a post-frame callback, which can outlive this
    // state on synchronous teardown — writing to the disposed notifier throws.
    if (!mounted) return;
    _bannerHeight.value = height;
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.backgroundColor ?? context.prego.colors.bgPrimary;
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

    // The top-navigation area handed to GlassScaffold: status-bar inset, then
    // the animated banner slot, then the bar row. GlassScaffold positions it
    // with an unconstrained height, so the banner growing simply pushes the
    // bar row down. The status-bar inset is owned by the leading SizedBox —
    // and removed from the bar's own MediaQuery so GlassAppBar's internal
    // SafeArea doesn't re-apply it below the banner. Both read the same
    // MediaQuery as every other inset in this build, keeping them in sync.
    final topBar = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: topPad),
        // Horizontal safe-area insets (landscape display cutouts) apply to the
        // banner card itself; the bar row below gets them from GlassAppBar's
        // own internal SafeArea.
        SafeArea(
          top: false,
          bottom: false,
          child: _AnimatedBannerSlot(banner: widget.banner, onHeightChanged: _onBannerHeightChanged),
        ),
        // The Builder confines removePadding's full-MediaQuery dependency (it
        // reads MediaQuery.of) to this leaf element — without it the whole
        // scaffold would rebuild on every keyboard viewInsets tick. The
        // captured [topNav] instance stays identical across those rebuilds, so
        // the bar itself short-circuits.
        Builder(
          builder: (barContext) => MediaQuery.removePadding(context: barContext, removeTop: true, child: topNav),
        ),
      ],
    );

    Widget scrollView = CustomScrollView(
      controller: _scrollController,
      physics: widget.scrollable ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
      slivers: [
        // When the body scrolls behind the bar, reserve space so the title
        // clears it. When it doesn't, GlassScaffold already insets the body
        // below the bar, so a spacer would double the gap. Skipped entirely when
        // the body owns its own scroll and insets itself ([reserveBarSpace]).
        // Follows the banner height so content rides the banner animation.
        if (extendBehind && widget.reserveBarSpace)
          SliverToBoxAdapter(
            child: ValueListenableBuilder<double>(
              valueListenable: _bannerHeight,
              builder: (context, bannerHeight, _) =>
                  SizedBox(height: topPad + topNav.preferredSize.height + bannerHeight),
            ),
          ),
        // Inline mode shows a fixed title in the bar, so there is no large
        // title sliver to scroll away.
        if (!inline)
          _LargeTitleSliver(
            title: widget.title,
            subtitle: widget.subtitle,
            scrollController: _scrollController,
          ),
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
      // top region — content beneath it stays fully interactive. The fade spans
      // the whole top area, banner included, so content dissolves before it
      // slides under the (opaque) banner exactly as it does under the bar.
      if (extendBehind)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: ValueListenableBuilder<double>(
              valueListenable: _bannerHeight,
              builder: (context, bannerHeight, _) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      backgroundColor.withMultipliedOpacity(0.9),
                      backgroundColor.withMultipliedOpacity(0.7),
                      backgroundColor.withMultipliedOpacity(0),
                    ],
                    stops: const [0, 0.8, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                height: topPad + topNav.preferredSize.height + bannerHeight,
              ),
            ),
          ),
        ),
      if (overlay != null) Positioned.fill(child: overlay),
    ];

    // GlassScaffold itself rebuilds per banner-animation frame: its
    // appBarHeight drives the body offset of non-extended bodies
    // ([extendBodyBehindBar] false), which has no listenable seam of its own.
    // The rebuild is cheap — every child above is a stable widget instance, so
    // their elements short-circuit and only GlassScaffold's layout math reruns.
    final scaffold = ValueListenableBuilder<double>(
      valueListenable: _bannerHeight,
      builder: (context, bannerHeight, _) => GlassScaffold(
        backgroundColor: backgroundColor,
        statusBarStyle: GlassStatusBarStyle.auto,
        extendBody: extendBehind,
        topEdgeFade: false, // Disable the top edge fade -- we use our own custom gradient
        bottomEdgeFade: false, // Disable the bottom edge fade -- we use our own custom gradient
        floatingActionButton: widget.floatingActionButton,
        bodyOverlays: bodyOverlays.isEmpty ? null : bodyOverlays,
        appBar: topBar,
        // The top bar is a Column (not a PreferredSizeWidget), so GlassScaffold
        // takes the bar extent from this parameter — the bar row plus the
        // banner's current animated height.
        appBarHeight: PregoTopNavigation.barHeight + bannerHeight,
        body: scrollView,
      ),
    );

    return _TopBarInsetScope(
      baseInset: topPad + PregoTopNavigation.barHeight,
      bannerHeight: _bannerHeight,
      child: scaffold,
    );
  }
}

/// Hosts [PregoGlassScaffold.banner] above the bar row and animates it in and
/// out as a height change.
///
/// Showing (banner `null` → non-null) grows the slot from zero to the banner's
/// intrinsic height; the bottom-aligned content slides down from under the
/// status bar. Hiding animates back to zero while a retained copy of the last
/// banner — kept because the live widget is already gone — slides up behind
/// the clip. The retained copy is dropped as soon as the collapse lands
/// (observed height back at zero), so a hidden slot keeps no live subtree.
///
/// The first layout adopts the banner's size without animating (AnimatedSize
/// semantics), so a screen pushed while a banner condition already holds shows
/// it in place rather than replaying the entrance.
class _AnimatedBannerSlot extends StatefulWidget {
  const _AnimatedBannerSlot({required this.banner, required this.onHeightChanged});

  /// The current banner, or `null` when nothing should show.
  final Widget? banner;

  /// Reports the slot's rendered height after every layout in which it
  /// changed — each frame of the show/hide animation, and once at rest.
  final ValueChanged<double> onHeightChanged;

  static const Duration _duration = Duration(milliseconds: 300);
  static const Curve _curve = Curves.easeInOutCubic;

  @override
  State<_AnimatedBannerSlot> createState() => _AnimatedBannerSlotState();
}

class _AnimatedBannerSlotState extends State<_AnimatedBannerSlot> {
  /// The last non-null banner. Kept while the exit animation runs so the real
  /// content is what slides away; cleared once the collapse lands.
  Widget? _retained;

  bool get _visible => widget.banner != null;

  @override
  void initState() {
    super.initState();
    _retained = widget.banner;
  }

  @override
  void didUpdateWidget(_AnimatedBannerSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Runs on every ancestor rebuild (including each frame of the height
    // animation), so this must stay a pure capture with no other side effects.
    if (widget.banner != null) _retained = widget.banner;
  }

  void _onHeightChanged(double height) {
    if (!mounted) return;
    widget.onHeightChanged(height);
    // The exit collapse has landed — drop the retained subtree so the hidden
    // banner stops occupying the element tree (tickers, semantics, memory).
    if (!_visible && height == 0 && _retained != null) {
      setState(() => _retained = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Order matters:
    //  - The observer wraps everything so it measures the animated size.
    //  - ClipRect sits OUTSIDE AnimatedSize: RenderAnimatedSize only clips
    //    while its animated size is smaller than the child's target size, so
    //    the exit (target zero, content overflowing upward) would otherwise
    //    paint the departing banner over the status bar.
    //  - Both bottomCenter alignments pin the content's bottom edge to the
    //    animated box's bottom edge, producing the slide-down entrance and
    //    slide-up exit.
    //  - Align(heightFactor: 0) sizes the hidden slot to zero while keeping
    //    the retained content laid out, which is what AnimatedSize animates
    //    toward during the exit.
    return _BannerSizeObserver(
      onHeightChanged: _onHeightChanged,
      child: ClipRect(
        child: AnimatedSize(
          duration: _AnimatedBannerSlot._duration,
          curve: _AnimatedBannerSlot._curve,
          alignment: Alignment.bottomCenter,
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: _visible ? 1 : 0,
            // The departing copy must be inert: not announced and not tappable.
            child: ExcludeSemantics(
              excluding: !_visible,
              child: IgnorePointer(
                ignoring: !_visible,
                child: _retained ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reports its child's laid-out height via [onHeightChanged] whenever it
/// changes. The callback is invoked post-frame so listeners may safely call
/// `setState`/notify — the same measure-and-report pattern as the session
/// detail composer measurement.
class _BannerSizeObserver extends SingleChildRenderObjectWidget {
  const _BannerSizeObserver({required this.onHeightChanged, required super.child});

  final ValueChanged<double> onHeightChanged;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBannerSizeObserver(onHeightChanged);

  @override
  void updateRenderObject(BuildContext context, _RenderBannerSizeObserver renderObject) {
    renderObject.onHeightChanged = onHeightChanged;
  }
}

class _RenderBannerSizeObserver extends RenderProxyBox {
  _RenderBannerSizeObserver(this.onHeightChanged);

  ValueChanged<double> onHeightChanged;
  double? _lastReportedHeight;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _lastReportedHeight) return;
    _lastReportedHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeightChanged(height));
  }
}

/// Publishes the top-bar area's geometry to descendants of a
/// [PregoGlassScaffold]: the static base inset (status bar + bar row) plus the
/// live banner height. The listenable's identity is stable across the banner
/// animation, so depending on this scope alone never causes per-frame
/// rebuilds — [PregoTopBarInsetBuilder] subscribes to the listenable where
/// per-frame tracking is wanted.
class _TopBarInsetScope extends InheritedWidget {
  const _TopBarInsetScope({
    required this.baseInset,
    required this.bannerHeight,
    required super.child,
  });

  /// Status-bar inset plus the bar row height — the top inset with no banner.
  final double baseInset;

  /// The banner slot's rendered height, following the show/hide animation.
  final ValueListenable<double> bannerHeight;

  @override
  bool updateShouldNotify(_TopBarInsetScope oldWidget) =>
      baseInset != oldWidget.baseInset || !identical(bannerHeight, oldWidget.bannerHeight);
}

/// Rebuilds [builder] with the current total top-bar inset of the enclosing
/// [PregoGlassScaffold] — status-bar inset + bar height + the banner's
/// animated height — tracking the [PregoGlassScaffold.banner] show/hide
/// animation frame-by-frame.
///
/// Use it in bodies that inset themselves below the bar (see
/// [PregoGlassScaffold.reserveBarSpace]) instead of computing
/// `MediaQuery.paddingOf(context).top + PregoTopNavigation.barHeight`, which
/// would ignore the banner. Per-frame rebuilds are confined to [builder]; put
/// anything that doesn't depend on the inset into [child], which is built once
/// and passed through.
///
/// Without an enclosing [PregoGlassScaffold] (e.g. a body pumped alone in a
/// widget test), [builder] gets the static bar inset.
class PregoTopBarInsetBuilder extends StatelessWidget {
  const PregoTopBarInsetBuilder({super.key, required this.builder, this.child});

  /// Built with the current top inset; re-invoked as the banner animates.
  final Widget Function(BuildContext context, double topInset, Widget? child) builder;

  /// Inset-independent subtree passed through to [builder] without rebuilding.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_TopBarInsetScope>();
    if (scope == null) {
      return builder(context, MediaQuery.paddingOf(context).top + PregoTopNavigation.barHeight, child);
    }
    return ValueListenableBuilder<double>(
      valueListenable: scope.bannerHeight,
      child: child,
      builder: (context, bannerHeight, child) => builder(context, scope.baseInset + bannerHeight, child),
    );
  }
}

class _LargeTitleSliver extends StatelessWidget {
  final String title;
  final String? subtitle;
  final ScrollController scrollController;
  const _LargeTitleSliver({
    required this.title,
    required this.subtitle,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final subtitle = this.subtitle;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          PregoSpacing.x3l,
          0,
          PregoSpacing.x3l,
          PregoSpacing.xl,
        ),
        child: ListenableBuilder(
          listenable: scrollController,
          builder: (context, _) {
            /// 0 while the large title is fully shown, 1 once it has collapsed into the
            /// bar. Delegates to [PregoTopNavigation.collapseProgressOf] — the single
            /// source of truth for the collapse — so the large-title sliver fades out in
            /// lockstep with the bar title fading in.
            final collapseProgress = PregoTopNavigation.collapseProgressOf(scrollController);
            // Fade via text alpha instead of an Opacity layer — no saveLayer per frame.
            final opacity = (1 - collapseProgress).clamp(0.0, 1.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: prego.textTheme.displayMd.medium.copyWith(
                    color: prego.colors.textPrimary.withMultipliedOpacity(opacity),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: prego.textTheme.textMd.regular.copyWith(
                      color: prego.colors.textSecondary.withMultipliedOpacity(opacity),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
