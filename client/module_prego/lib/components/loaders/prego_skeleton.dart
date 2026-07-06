/// Skeleton loading primitives for the Prego design system.
///
/// The designed loading state for content-bearing surfaces: pill-shaped
/// placeholder bars that fade toward their trailing edge, swept by a moving
/// sheen while real data loads. Compose a bespoke layout from
/// [PregoSkeletonBar] and [PregoSkeletonListTile] and wrap it in
/// [PregoShimmer], or drop in [PregoSkeletonList] — the ready-made shimmering
/// list for list screens loading their first page.
library;

import "dart:async";

import "package:flutter/material.dart";

import "../../theme/prego_theme.dart";

/// Animates a shimmer sheen across [child].
///
/// A translucent highlight band sweeps from the leading to the trailing edge,
/// restricted to [child]'s opaque pixels ([BlendMode.srcATop]) so the gaps
/// between skeleton shapes stay untouched. The mask is a single saveLayer for
/// the whole region — wrap one [PregoShimmer] around a screen's entire
/// skeleton, never one per row. The child renders unmasked when [enabled] is
/// false or the platform requests reduced motion — the static fade of the
/// bars still reads as a loading state.
///
/// To avoid a one-frame skeleton flash on fast loads, the region stays laid
/// out but invisible for [appearDelay], then fades in.
///
/// Skeletons are decorative: descendants are excluded from semantics, and
/// [semanticLabel] (when given) is announced in their place.
class PregoShimmer extends StatefulWidget {
  const PregoShimmer({
    super.key,
    required this.child,
    this.enabled = true,
    this.period = const Duration(milliseconds: 1500),
    this.appearDelay = const Duration(milliseconds: 300),
    this.highlightColor,
    this.semanticLabel,
  });

  final Widget child;

  /// Whether the sheen sweeps. The skeleton shapes render either way.
  final bool enabled;

  /// Time for one full sweep across the child.
  final Duration period;

  /// How long the skeleton stays invisible before fading in, so loads that
  /// finish quickly never flash it. [Duration.zero] shows it immediately.
  final Duration appearDelay;

  /// Peak colour of the sheen band. Defaults to a translucent white, which
  /// lightens the grey bars in both themes.
  final Color? highlightColor;

  /// Announced to screen readers in place of the decorative skeleton.
  final String? semanticLabel;

  @override
  State<PregoShimmer> createState() => _PregoShimmerState();
}

class _PregoShimmerState extends State<PregoShimmer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// Sweep position in multiples of the child's width. The band (20% wide,
  /// centred at 0.5 + value) is fully off-screen outside [-0.6, 0.6]; the
  /// extra margin below/above gives it a clean entry and a short rest between
  /// sweeps.
  static const double _slideMin = -0.7;
  static const double _slideMax = 1.1;

  late final AnimationController _slide = AnimationController.unbounded(vsync: this)
    ..value = _slideMin;

  late bool _visible = widget.appearDelay == Duration.zero;
  Timer? _appearTimer;

  bool get _shouldAnimate {
    if (!widget.enabled || !_visible) return false;
    // MediaQuery only carries Android's "Remove animations"; iOS "Reduce
    // Motion" surfaces solely through accessibilityFeatures.reduceMotion.
    if (MediaQuery.disableAnimationsOf(context)) return false;
    return !View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_visible) _scheduleAppear();
  }

  void _scheduleAppear() {
    _appearTimer?.cancel();
    _appearTimer = Timer(widget.appearDelay, () {
      if (!mounted) return;
      setState(() => _visible = true);
      _syncAnimation();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(PregoShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) _slide.stop();
    if (oldWidget.appearDelay != widget.appearDelay && !_visible) {
      if (widget.appearDelay == Duration.zero) {
        _appearTimer?.cancel();
        _visible = true;
      } else {
        _scheduleAppear();
      }
    }
    _syncAnimation();
  }

  @override
  void didChangeAccessibilityFeatures() {
    // Reduce Motion toggles don't reach MediaQuery on iOS; re-evaluate the
    // sweep when the platform's accessibility features change.
    if (!mounted) return;
    setState(() {});
    _syncAnimation();
  }

  void _syncAnimation() {
    if (_shouldAnimate && !_slide.isAnimating) {
      _slide.repeat(min: _slideMin, max: _slideMax, period: widget.period);
    } else if (!_shouldAnimate && _slide.isAnimating) {
      _slide.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appearTimer?.cancel();
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget result = ExcludeSemantics(child: widget.child);

    if (_shouldAnimate) {
      final highlight = widget.highlightColor ?? Colors.white.withValues(alpha: 0.30);
      // In RTL the band sweeps right-to-left so it still travels leading →
      // trailing.
      final direction = switch (Directionality.of(context)) {
        TextDirection.ltr => 1.0,
        TextDirection.rtl => -1.0,
      };
      // A horizontal band, matching the bars' own horizontal fades. Kept
      // untilted on purpose: an x-only translation traverses a tilted band's
      // gradient line at a height-dependent rate, which makes the entry/exit
      // margins wrong on tall regions.
      result = RepaintBoundary(
        child: AnimatedBuilder(
          animation: _slide,
          child: result,
          builder: (context, child) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [highlight.withValues(alpha: 0), highlight, highlight.withValues(alpha: 0)],
              stops: const [0.4, 0.5, 0.6],
              transform: _SlidingGradientTransform(slidePercent: _slide.value * direction),
            ).createShader(bounds),
            child: child,
          ),
        ),
      );
    }

    // Held invisible (but laid out, so nothing jumps) until the appear delay
    // elapses, then faded in.
    result = AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: result,
    );

    final semanticLabel = widget.semanticLabel;
    if (semanticLabel == null) return result;
    return Semantics(container: true, label: semanticLabel, child: result);
  }
}

/// Translates the sweep gradient horizontally by [slidePercent] of the
/// masked area's width.
class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
}

/// A single pill-shaped skeleton bar that fades toward its trailing edge.
class PregoSkeletonBar extends StatelessWidget {
  const PregoSkeletonBar({
    super.key,
    required this.height,
    this.width,
    this.color,
  });

  final double height;

  /// Fixed width; null fills the available width.
  final double? width;

  /// Solid (leading) colour of the fade. Defaults to the quaternary
  /// foreground, which the fade dissolves into the screen background.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.prego.colors.fgQuaternary;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PregoRadius.full),
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

/// A two-line list-row skeleton: a title bar over a shorter indented detail
/// bar, closed by the hairline bottom border list rows carry.
class PregoSkeletonListTile extends StatelessWidget {
  const PregoSkeletonListTile({
    super.key,
    this.titleWidthFraction = 1.0,
  });

  /// Fraction of the row's content width the title bar spans. Varying this
  /// across rows keeps the placeholder list looking organic.
  final double titleWidthFraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PregoSpacing.lg),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.prego.colors.borderTertiary)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: PregoSpacing.xxs,
        children: [
          // Title slot: a 20px bar centred in its 24px line box.
          SizedBox(
            height: 24,
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: titleWidthFraction,
              child: const Align(
                alignment: AlignmentDirectional.centerStart,
                child: PregoSkeletonBar(height: 20),
              ),
            ),
          ),
          // Detail slot: a fixed-width 14px bar in its 20px line box, indented
          // like the metadata row under a list title.
          const SizedBox(
            height: 20,
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: PregoSpacing.xl),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: PregoSkeletonBar(height: 14, width: 99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The ready-made shimmering list skeleton: [itemCount] two-line rows with a
/// varied title-width rhythm, wrapped in a [PregoShimmer].
class PregoSkeletonList extends StatelessWidget {
  const PregoSkeletonList({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsetsDirectional.symmetric(horizontal: PregoSpacing.xl, vertical: 10),
    this.semanticLabel,
  });

  final int itemCount;

  final EdgeInsetsGeometry padding;

  /// Announced to screen readers in place of the decorative rows.
  final String? semanticLabel;

  /// Title-bar width fractions cycled across rows; the variation keeps the
  /// placeholder from reading as a striped pattern.
  static const List<double> _titleWidths = [0.74, 0.51, 0.51, 0.83, 1.0, 0.51];

  @override
  Widget build(BuildContext context) {
    return PregoShimmer(
      semanticLabel: semanticLabel,
      child: Padding(
        padding: padding,
        child: Column(
          spacing: 10,
          children: [
            for (var i = 0; i < itemCount; i++)
              PregoSkeletonListTile(titleWidthFraction: _titleWidths[i % _titleWidths.length]),
          ],
        ),
      ),
    );
  }
}
