/// The AI activity indicator: a sparkle that twinkles while an agent works.
library;

import "package:flutter/material.dart";

import "../../motion/prego_reduced_motion.dart";
import "../../theme/prego_theme.dart";
import "../../utils/lerp_utils.dart";

/// A sparkle marking AI activity, twinkling while [animate] is set.
///
/// The loop runs through three designed keyframes — solid brand, hollow
/// outline, faded solid — shrinking slightly as it hollows out, so it reads as
/// a pulse rather than a spinner. With [animate] false it rests on the first of
/// them, a solid brand sparkle: the same still frame the platform's
/// reduced-motion preference forces, so a caller can use it as a static "has
/// activity" mark without a second widget.
///
/// The sparkle is decorative — it always accompanies a label that carries the
/// meaning, so it is excluded from semantics.
class PregoAiLoader extends StatefulWidget {
  const PregoAiLoader({
    super.key,
    this.size = 16,
    this.animate = true,
    this.phase = 0,
  });

  /// Side of the square the sparkle is painted into. Defaults to the 16px the
  /// design uses inline with a text-sm label.
  final double size;

  /// Whether the sparkle twinkles. When false it rests on the solid keyframe.
  final bool animate;

  /// Fraction of the loop [0, 1) this sparkle starts at.
  ///
  /// Several sparkles built in the same frame would otherwise twinkle in
  /// lockstep — a list of running projects reads as one flickering block
  /// rather than several independently working agents. Callers pass a value
  /// derived from something stable about the row, so a given row's phase
  /// survives a rebuild. Ignored while the sparkle is at rest, which always
  /// shows the solid keyframe.
  final double phase;

  @override
  State<PregoAiLoader> createState() => _PregoAiLoaderState();
}

class _PregoAiLoaderState extends State<PregoAiLoader>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, PregoReducedMotionStateMixin {
  /// One full twinkle. Slow enough to read as breathing rather than blinking.
  static const Duration _period = Duration(milliseconds: 1400);

  /// Constructed unstarted: whether it may run depends on [MediaQuery], which
  /// cannot be read until `didChangeDependencies`.
  late final AnimationController _loop = AnimationController(vsync: this, duration: _period);

  @override
  bool get motionEnabled => widget.animate;

  @override
  void startMotion() {
    if (!_loop.isAnimating) _loop.repeat();
  }

  @override
  void stopMotion() {
    if (_loop.isAnimating) _loop.stop();
    // Rest on the solid keyframe rather than wherever the loop was cut.
    _loop.value = 0;
  }

  @override
  void didUpdateWidget(PregoAiLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) syncMotion();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    return ExcludeSemantics(
      // The loop repaints this sparkle every frame; without a boundary of its
      // own it would repaint whatever layer it was composited into — the whole
      // list row. CustomPaint adds no boundary itself.
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _AiLoaderPainter(
            repaint: _loop,
            // A resting sparkle always shows the solid keyframe, so the phase
            // offset only applies while the loop runs.
            phase: motionAllowed ? widget.phase : 0,
            solid: colors.textPrimaryOnBrand,
            outline: colors.textPrimary,
            faded: colors.textDisabled,
          ),
        ),
      ),
    );
  }
}

/// Paints the sparkle at the keyframe [repaint] currently sits on.
///
/// Driven by `repaint:` rather than an [AnimatedBuilder]: the render object
/// listens to the animation and repaints, without rebuilding an element sixty
/// times a second. The cost is that [shouldRepaint] is only consulted when the
/// widget rebuilds, so it must compare everything *except* the animation.
class _AiLoaderPainter extends CustomPainter {
  _AiLoaderPainter({
    required Animation<double> repaint,
    required this.phase,
    required this.solid,
    required this.outline,
    required this.faded,
  }) : _progress = repaint,
       super(repaint: repaint);

  final double phase;

  /// The three designed keyframes: a solid brand sparkle, a hollow outline, and
  /// a faded solid one.
  final Color solid;
  final Color outline;
  final Color faded;

  final Animation<double> _progress;

  /// The sparkle's coordinate space, from the source icon.
  static const double _viewBox = 24;

  /// Stroke width in [_viewBox] units. The canvas is scaled rather than the
  /// path, so this scales down with the geometry (1.33px at a 16px sparkle).
  static const double _strokeWidth = 2;

  /// Tabler's `sparkle-2` outline (MIT), a single path in a 24x24 box.
  ///
  /// It is a stroke *centreline*, so filling it alone yields a silhouette inset
  /// by half a stroke. The solid keyframes therefore paint the fill *and* the
  /// stroke in one colour — the stroke outsets the fill back to the true solid
  /// shape — and the outline keyframe just drops the fill away. Interpolating
  /// the fill's alpha instead of switching paint styles keeps the sparkle the
  /// same size across the whole loop.
  static final Path _sparkle = Path()
    ..moveTo(12, 3)
    ..cubicTo(12.375, 3, 12.711, 3.231, 12.846, 3.581)
    ..lineTo(14.496, 7.871)
    ..arcToPoint(const Offset(16.128, 9.504), radius: const Radius.circular(2.85), clockwise: false)
    ..lineTo(20.419, 11.154)
    ..arcToPoint(const Offset(20.419, 12.846), radius: const Radius.circular(0.906))
    ..lineTo(16.129, 14.496)
    ..arcToPoint(const Offset(14.496, 16.128), radius: const Radius.circular(2.84), clockwise: false)
    ..lineTo(12.846, 20.419)
    ..arcToPoint(const Offset(11.154, 20.419), radius: const Radius.circular(0.906))
    ..lineTo(9.504, 16.129)
    ..arcToPoint(const Offset(7.872, 14.496), radius: const Radius.circular(2.84), clockwise: false)
    ..lineTo(3.581, 12.846)
    ..arcToPoint(const Offset(3.581, 11.154), radius: const Radius.circular(0.906))
    ..lineTo(7.871, 9.504)
    ..arcToPoint(const Offset(9.504, 7.872), radius: const Radius.circular(2.84), clockwise: false)
    ..lineTo(11.154, 3.581)
    ..arcToPoint(const Offset(12, 3), radius: const Radius.circular(0.91))
    ..close();

  /// Where each keyframe sits in the loop. The solid brand sparkle holds for
  /// the back third, so the twinkle has a rest rather than reading as a strobe.
  static const double _outlineAt = 0.4;
  static const double _fadedAt = 0.7;

  @override
  void paint(Canvas canvas, Size size) {
    final t = (_progress.value + phase) % 1.0;
    final (color, fillOpacity, scale) = _keyframe(t);

    canvas.save();
    // Pulse about the sparkle's centre, then map the source box onto the paint
    // area. Scaling the canvas (not the path) carries the stroke width with it
    // and keeps the path allocation-free.
    final centre = Offset(size.width / 2, size.height / 2);
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(scale);
    canvas.translate(-centre.dx, -centre.dy);
    canvas.scale(size.shortestSide / _viewBox);

    canvas.drawPath(
      _sparkle,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: color.a * fillOpacity),
    );
    canvas.drawPath(
      _sparkle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.restore();
  }

  /// The colour, fill opacity and scale of the sparkle at [t] in the loop:
  /// solid brand at full size, hollowing out and shrinking to the outline, then
  /// filling back in as a faded sparkle before returning to brand.
  (Color, double, double) _keyframe(double t) {
    if (t < _outlineAt) {
      final p = t / _outlineAt;
      return (
        lerpColorNonNull(solid, outline, p),
        1 - p,
        lerpDoubleNonNull(1.0, 0.86, p),
      );
    }
    if (t < _fadedAt) {
      final p = (t - _outlineAt) / (_fadedAt - _outlineAt);
      return (
        lerpColorNonNull(outline, faded, p),
        p,
        lerpDoubleNonNull(0.86, 0.92, p),
      );
    }
    final p = (t - _fadedAt) / (1 - _fadedAt);
    return (
      lerpColorNonNull(faded, solid, p),
      1,
      lerpDoubleNonNull(0.92, 1.0, p),
    );
  }

  @override
  bool shouldRepaint(_AiLoaderPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.solid != solid ||
        oldDelegate.outline != outline ||
        oldDelegate.faded != faded;
  }
}
