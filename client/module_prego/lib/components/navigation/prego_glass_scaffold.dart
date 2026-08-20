import "package:cupertino_ui/cupertino_ui.dart" show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import "package:flutter/rendering.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";

import "../../module_prego.dart";
import "../../utils/color_extensions.dart";
import "prego_top_bar_inset.dart" as top_bar;

/// Where [PregoGlassScaffold] parks its
/// [PregoGlassScaffold.floatingActionButton].
enum PregoFloatingActionAlignment() {
  /// Trailing edge — Flutter's [FloatingActionButtonLocation.endFloat], the
  /// placement for a corner action such as add-project or new-session.
  end,

  /// Horizontally centred, at the same height — for an action the page
  /// presents as its own call to action rather than a corner affordance (the
  /// bridge onboarding's "Need help?" pill).
  center,
}

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
/// practice, a fixed-title [titleMode] (a collapsing large title has nothing
/// to reserve against here).
///
/// Set [titleMode] to [PregoTopNavigationTitleMode.inline] for a fixed,
/// centred title (and [subtitleText]) in the bar — the showcase's
/// inline-title pattern (`_InlineTitleDemo`) — instead of the large title
/// that collapses on scroll. Use it for screens whose body owns its own
/// scroll (e.g. a chat with a reversed controller), where a collapsing large
/// title has nothing to collapse against. Set it to
/// [PregoTopNavigationTitleMode.backLeading] for the muted title block beside
/// the back button, with the caller-composed [subtitle] widget (typically a
/// [PregoNavSubtitle]) beneath it; like inline, this mode hosts no large
/// title below the bar.
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
class const PregoGlassScaffold({
    super.key,
    /// Primary title — shown large below the bar and, once collapsed, inline.
  required final String title,
    /// The page's content slivers, rendered below the auto-injected spacer and
  /// large title. Non-scrolling states (loading, empty, error) should be a
  /// single [SliverFillRemaining].
  required final List<Widget> slivers,
    /// The back-leading title block's second line — a self-contained,
  /// caller-composed widget (typically a [PregoNavSubtitle]) holding
  /// everything the row needs: icon, status dot, tap affordance.
  /// [PregoTopNavigationTitleMode.backLeading] only; null renders the title
  /// on its own.
  final Widget? subtitle,
    /// Optional second text line rendered beneath the [title] in the bar's own
  /// muted style — the large title's second line (collapsing mode) or the
  /// centred inline subtitle (inline mode).
  final String? subtitleText,
    /// How the bar presents its title — collapsing large title (default), fixed
  /// centred inline title, or the back-leading title block. See the class doc.
  final PregoTopNavigationTitleMode titleMode = PregoTopNavigationTitleMode.collapsing,
    /// Weight of the back-leading title line. Back-leading [titleMode] only.
  final PregoNavLeadingTitleEmphasis leadingTitleEmphasis = PregoNavLeadingTitleEmphasis.muted,
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
  final Widget? banner,
    /// Trailing bar actions. Build these with PregoButtonsIconGlass components so
  /// they match the leading/back button.
  final List<Widget>? actions,
    /// Overrides the leading slot entirely. Takes precedence over [onBack] and
  /// [automaticallyImplyLeading].
  final Widget? leading,
    /// When set (and [leading] is null), renders a glass back button that invokes
  /// this callback instead of relying on the enclosing navigator.
  final VoidCallback? onBack,
    /// Whether the bar may infer a back button from the navigator when neither
  /// [leading] nor [onBack] is supplied.
  final bool automaticallyImplyLeading = true,
    /// Optional floating action button, hosted by the standalone [Scaffold].
  final Widget? floatingActionButton,
    /// Where [floatingActionButton] sits horizontally. Defaults to the trailing
  /// edge.
  final PregoFloatingActionAlignment floatingActionAlignment = PregoFloatingActionAlignment.end,
    /// A full-screen overlay painted above the body but below the bar, so the
  /// bar (and its back button) stays interactive while it is shown. Use for a
  /// modal scrim such as a blocking loading indicator. Null shows nothing.
  final Widget? overlay,
    /// When set, an in-scroll refresh control opens below the top bar and pushes
  /// the caller-provided content down while it is pulled.
  final Future<void> Function()? onRefresh,
    /// Page background painted behind the glass. Defaults to `bgSurface1`.
  final Color? backgroundColor,
    /// Whether the body scrolls behind the bar. Defaults to `true`. Set `false`
  /// for bodies with pinned slivers that must pin below the bar.
  final bool extendBodyBehindBar = true,
    /// Whether to inject the top spacer that pushes the first content below the
  /// bar. Defaults to `true`. Set `false` when the body owns its own scroll and
  /// insets itself (see the class doc).
  final bool reserveBarSpace = true,
    /// Whether the page itself scrolls. Defaults to `true`
  /// ([AlwaysScrollableScrollPhysics]). Set `false`
  /// ([NeverScrollableScrollPhysics]) for screens whose body fills the viewport
  /// and owns its own scroll (e.g. a reversed chat list): the outer page then
  /// can't overscroll/bounce, so a drag that starts outside the inner list —
  /// e.g. on a pinned composer — no longer drags the whole page. Only the body's
  /// own scrollable moves. Incompatible with [onRefresh], which needs the page
  /// to be draggable.
  final bool scrollable = true,
  }) extends StatefulWidget {
  this : assert(
         scrollable || onRefresh == null,
         "onRefresh requires scrollable to be true (the refresh control needs a draggable page)",
       );

  @override
  State<PregoGlassScaffold> createState() => _PregoGlassScaffoldState();
}

class _PregoGlassScaffoldState() extends State<PregoGlassScaffold> {
  final ScrollController _scrollController = ScrollController();

  /// The banner slot's currently rendered height, measured after each layout.
  /// While the banner animates, this follows the animation one frame behind
  /// (measure → notify → rebuild); every inset derived from the bar area — the
  /// content spacer, the scroll-edge gradient, GlassScaffold's non-extended
  /// body offset, and [PregoTopBarInsetBuilder] consumers — listens to it, so
  /// content tracks the moving bar and is exact at rest.
  final ValueNotifier<double> _bannerHeight = ValueNotifier<double>(0);

  /// The base inset captured during the latest build, combined with
  /// [_bannerHeight] when publishing to [top_bar.pregoRootTopBarInset].
  double _baseInset = 0;

  /// The root overlay this scaffold publishes geometry for.
  OverlayState? _rootOverlay;

  final top_bar.PregoRootTopBarInsetOwner _rootInsetOwner = top_bar.PregoRootTopBarInsetOwner();

  /// The collapsing title's rendered extent, including its bottom spacing.
  /// Used to paint the refresh indicator below the title without assuming a
  /// fixed text scale or whether a subtitle is present.
  double _largeTitleHeight = 0;

  /// Total space currently opened by the refresh sliver. Unlike the scroll
  /// offset, this stays continuous when Cupertino converts part of the
  /// overscroll into its held refresh extent.
  double _refreshPulledExtent = 0;

  @override
  void initState() {
    super.initState();
    _bannerHeight.addListener(_publishRootInset);
  }

  @override
  void dispose() {
    _bannerHeight.removeListener(_publishRootInset);
    final rootOverlay = _rootOverlay;
    if (rootOverlay != null) {
      top_bar.clearPregoRootTopBarInset(overlay: rootOverlay, owner: _rootInsetOwner);
    }
    _scrollController.dispose();
    _bannerHeight.dispose();
    super.dispose();
  }

  /// Publishes this scaffold's live top-bar inset so app-wide presentation
  /// outside any route can clear the top bar and a visible banner. The most
  /// recently built (topmost) scaffold wins.
  void _publishRootInset() {
    if (!mounted) return;
    final rootOverlay = _rootOverlay;
    if (rootOverlay == null) return;
    top_bar.publishPregoRootTopBarInset(
      overlay: rootOverlay,
      owner: _rootInsetOwner,
      inset: _baseInset + _bannerHeight.value,
    );
  }

  /// The floating action handed to the standalone [Scaffold], positioned per
  /// [PregoGlassScaffold.floatingActionAlignment].
  ///
  /// The [Scaffold] has no [FloatingActionButtonLocation], so the action always
  /// lands on [FloatingActionButtonLocation.endFloat]. Rather than reimplement that
  /// slot's vertical placement — which already clears the keyboard, the home
  /// indicator and any snack bar — the centred variant widens the action to
  /// the full content width and centres the caller's widget inside it.
  /// `endFloat` then insets that box by the same margin on both sides, so its
  /// child lands exactly on the page's centre line. The surrounding box is
  /// empty, and an unfilled [Center] hit-tests only its child, so the widened
  /// action swallows no taps.
  Widget? get _floatingActionButton {
    final fab = widget.floatingActionButton;
    if (fab == null) return null;
    return switch (widget.floatingActionAlignment) {
      PregoFloatingActionAlignment.end => fab,
      // Measured from the action's own loose constraints (the scaffold's size)
      // rather than the window, so a narrow split-pane centres on the pane.
      PregoFloatingActionAlignment.center => LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: (constraints.maxWidth - 2 * kFloatingActionButtonMargin).clamp(0.0, double.infinity),
          // heightFactor: 1 keeps the box the child's height; without it the
          // Center would expand to the full scaffold height.
          child: Center(heightFactor: 1, child: fab),
        ),
      ),
    };
  }

  void _onBannerHeightChanged(double height) {
    // The measurement arrives in a post-frame callback, which can outlive this
    // state on synchronous teardown — writing to the disposed notifier throws.
    if (!mounted) return;
    _bannerHeight.value = height;
  }

  void _onLargeTitleHeightChanged(double height) {
    if (!mounted) return;
    _largeTitleHeight = height;
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.backgroundColor ?? context.prego.colors.bgSurface1;
    // The status-bar icons have to contrast with this scaffold's surface, so
    // they follow the active palette's brightness. GlassStatusBarStyle.auto
    // would read the *device* brightness instead, which ignores an in-app
    // appearance choice: picking Light on a phone in dark mode would leave
    // white icons on a light surface (and the reverse).
    final statusBarStyle = switch (context.prego.colors.brightness) {
      Brightness.dark => GlassStatusBarStyle.light,
      Brightness.light => GlassStatusBarStyle.dark,
    };
    final topPad = MediaQuery.paddingOf(context).top;
    final extendBehind = widget.extendBodyBehindBar;
    final collapsing = widget.titleMode == PregoTopNavigationTitleMode.collapsing;
    final onRefresh = widget.onRefresh;

    // The bar. It shares this scaffold's [_scrollController] so its collapsing
    // title fades in as the large-title sliver below scrolls away.
    final topNav = PregoTopNavigation(
      title: widget.title,
      subtitle: widget.subtitle,
      subtitleText: widget.subtitleText,
      titleMode: widget.titleMode,
      leadingTitleEmphasis: widget.leadingTitleEmphasis,
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

    final scrollView = CustomScrollView(
      controller: _scrollController,
      // CupertinoSliverRefreshControl needs overscroll even on platforms whose
      // default physics clamp at the edge. Its sliver extent is what moves the
      // page content down during a pull instead of painting over it.
      physics: !widget.scrollable
          ? const NeverScrollableScrollPhysics()
          : onRefresh != null
          ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
          : const AlwaysScrollableScrollPhysics(),
      slivers: [
        // The refresh sliver must receive the scroll view's leading overscroll,
        // so it precedes the bar spacer. Shift only its painted indicator below
        // the live bar and large-title insets; the sliver itself opens at the
        // scroll origin and pushes the caller-provided content down.
        if (onRefresh != null)
          CupertinoSliverRefreshControl(
            onRefresh: onRefresh,
            builder: (context, refreshState, pulledExtent, triggerDistance, indicatorExtent) {
              _refreshPulledExtent = refreshState == RefreshIndicatorMode.inactive ? 0 : pulledExtent;
              final indicator = CupertinoSliverRefreshControl.buildRefreshIndicator(
                context,
                refreshState,
                pulledExtent,
                triggerDistance,
                indicatorExtent,
              );
              // A non-extended body already begins below the bar, but its
              // collapsing title still precedes the caller-provided content.
              if (!extendBehind) {
                return collapsing
                    ? Transform.translate(offset: Offset(0, _largeTitleHeight), child: indicator)
                    : indicator;
              }

              return ValueListenableBuilder<double>(
                valueListenable: _bannerHeight,
                child: indicator,
                builder: (context, bannerHeight, indicator) => Transform.translate(
                  offset: Offset(
                    0,
                    topPad + topNav.preferredSize.height + bannerHeight + (collapsing ? _largeTitleHeight : 0),
                  ),
                  child: indicator,
                ),
              );
            },
          ),
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
        // The fixed-title modes (inline, back-leading) show their title in the
        // bar, so there is no large title sliver to scroll away.
        if (collapsing)
          _LargeTitleSliver(
            title: widget.title,
            subtitle: widget.subtitleText,
            scrollController: _scrollController,
            onHeightChanged: _onLargeTitleHeightChanged,
            pulledExtent: onRefresh == null ? null : () => _refreshPulledExtent,
          ),
        ...widget.slivers,
      ],
    );

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
                      backgroundColor.withMultipliedOpacity(0.98),
                      backgroundColor.withMultipliedOpacity(0.88),
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

    // GlassScaffold's appBarHeight drives the body offset only for a
    // NON-extended body ([extendBodyBehindBar] false), which has no listenable
    // seam of its own — so that case rebuilds the scaffold per banner-animation
    // frame. With an extended body the banner height is irrelevant to
    // GlassScaffold (the body is Positioned.fill behind the bar, and our own
    // gradient/spacer carry the fade), so it is built once and the per-frame
    // tracking stays with the spacer, gradient and inset scope. The rebuild,
    // when it runs, is cheap: every child above is a stable widget instance, so
    // their elements short-circuit and only GlassScaffold's layout math reruns.
    GlassScaffold buildScaffold(double bannerHeight) => GlassScaffold(
      backgroundColor: backgroundColor,
      statusBarStyle: statusBarStyle,
      extendBody: extendBehind,
      topEdgeFade: false, // Disable the top edge fade -- we use our own custom gradient
      bottomEdgeFade: false, // Disable the bottom edge fade -- we use our own custom gradient
      bodyOverlays: bodyOverlays.isEmpty ? null : bodyOverlays,
      appBar: topBar,
      // The top bar is a Column (not a PreferredSizeWidget), so GlassScaffold
      // takes the bar extent from this parameter — the bar row plus the
      // banner's current animated height.
      appBarHeight: PregoTopNavigation.barHeight + bannerHeight,
      body: scrollView,
    );

    final Widget scaffold = extendBehind
        ? buildScaffold(0)
        : ValueListenableBuilder<double>(
            valueListenable: _bannerHeight,
            builder: (context, bannerHeight, _) => buildScaffold(bannerHeight),
          );

    // Publish the root inset seam before building the bar area so app-wide
    // presentation created during this frame already sees current geometry.
    final rootOverlay = Overlay.maybeOf(context, rootOverlay: true);
    if (!identical(_rootOverlay, rootOverlay)) {
      final previousOverlay = _rootOverlay;
      if (previousOverlay != null) {
        top_bar.clearPregoRootTopBarInset(overlay: previousOverlay, owner: _rootInsetOwner);
      }
      _rootOverlay = rootOverlay;
    }
    _baseInset = topPad + PregoTopNavigation.barHeight;
    _publishRootInset();

    // Remove this wrapper once liquid_glass_widgets migrates from the Flutter SDK Material and Cupertino libraries to material_ui and cupertino_ui.
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _floatingActionButton,
      body: top_bar.PregoTopBarInsetScope(
        baseInset: topPad + PregoTopNavigation.barHeight,
        bannerHeight: _bannerHeight,
        child: scaffold,
      ),
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
class const _AnimatedBannerSlot({
  /// The current banner, or `null` when nothing should show.
  required final Widget? banner,
  /// Reports the slot's rendered height after every layout in which it
  /// changed — each frame of the show/hide animation, and once at rest.
  required final ValueChanged<double> onHeightChanged}) extends StatefulWidget {
  static const Duration _duration = Duration(milliseconds: 300);
  static const Curve _curve = Curves.easeInOutCubic;

  @override
  State<_AnimatedBannerSlot> createState() => _AnimatedBannerSlotState();
}

class _AnimatedBannerSlotState() extends State<_AnimatedBannerSlot> {
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
    // Runs when the enclosing scaffold rebuilds this slot (a banner toggle, a
    // MediaQuery change, an ancestor rebuild) — not per animation frame, since
    // AnimatedSize animates in layout without rebuilding here. Keep it a pure
    // capture with no other side effects.
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
    return _HeightObserver(
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
class const _HeightObserver({required final ValueChanged<double> onHeightChanged, required super.child}) extends SingleChildRenderObjectWidget {
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHeightObserver(onHeightChanged);

  @override
  void updateRenderObject(BuildContext context, _RenderHeightObserver renderObject) {
    renderObject.onHeightChanged = onHeightChanged;
  }
}

class _RenderHeightObserver(var ValueChanged<double> onHeightChanged) extends RenderProxyBox {
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

/// Keeps its child fixed while a preceding refresh sliver opens space.
///
/// The translation is read at paint time because Cupertino changes the scroll
/// offset while converting overscroll into a held refresh extent. A widget-level
/// transform rebuilt during that correction can observe the new scroll offset
/// with the old sliver geometry for one frame, making the title jump.
class const _OverscrollPinnedBox({required final ValueGetter<double> pulledExtent, required super.child}) extends SingleChildRenderObjectWidget {
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderOverscrollPinnedBox(pulledExtent);

  @override
  void updateRenderObject(BuildContext context, _RenderOverscrollPinnedBox renderObject) {
    renderObject.updatePulledExtent(pulledExtent);
  }
}

class _RenderOverscrollPinnedBox(var ValueGetter<double> _pulledExtent) extends RenderProxyBox {
  void updatePulledExtent(ValueGetter<double> value) {
    _pulledExtent = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  double get _translationY => -_pulledExtent();

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    context.paintChild(child, offset.translate(0, _translationY));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    final paintOffset = Offset(0, _translationY);
    return result.addWithPaintOffset(
      offset: paintOffset,
      position: position,
      hitTest: (result, transformed) => child.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    transform.translateByDouble(0, _translationY, 0, 1);
  }
}

class const _LargeTitleSliver({
    required final String title,
    required final String? subtitle,
    required final ScrollController scrollController,
    required final ValueChanged<double> onHeightChanged,
    required final ValueGetter<double>? pulledExtent,
  }) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final subtitle = this.subtitle;
    final pulledExtent = this.pulledExtent;

    final titleContent = Padding(
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
    );

    return SliverToBoxAdapter(
      child: _HeightObserver(
        onHeightChanged: onHeightChanged,
        child: pulledExtent == null
            ? titleContent
            : _OverscrollPinnedBox(pulledExtent: pulledExtent, child: titleContent),
      ),
    );
  }
}
