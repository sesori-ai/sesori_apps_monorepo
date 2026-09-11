/// The thread activity sparkle: rotating outline → settled unread fill.
library;

import "dart:async";
import "dart:math" as math;

import "package:clock/clock.dart";
import "package:flutter/foundation.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";

import "../../motion/prego_reduced_motion.dart";
import "../../theme/prego_theme.dart";
import "../../utils/lerp_utils.dart";

/// One device-clock-aligned repaint source shared by all Flutter sparkles.
///
/// A recursive one-shot timer avoids `Timer.periodic` drift. It exists only
/// while at least one visible, motion-enabled working sparkle listens.
final class _AiLoaderLoopClock._() extends ChangeNotifier {
  static final instance = _AiLoaderLoopClock._();
  static const _period = Duration(seconds: 2);
  static const _step = Duration(milliseconds: 25);

  Timer? _timer;
  double _angle = 0;

  double get angle => _angle;

  @override
  void addListener(VoidCallback listener) {
    final needsTimer = !hasListeners;
    super.addListener(listener);
    if (needsTimer) {
      _sampleClock();
      _scheduleNextStep();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _scheduleNextStep() {
    final remainder = clock.now().millisecondsSinceEpoch % _step.inMilliseconds;
    _timer = Timer(Duration(milliseconds: _step.inMilliseconds - remainder), () {
      _timer = null;
      _sampleClock();
      notifyListeners();
      if (hasListeners) _scheduleNextStep();
    });
  }

  void _sampleClock() {
    final now = clock.now().millisecondsSinceEpoch;
    final sampled = now - now % _step.inMilliseconds;
    _angle = (sampled % _period.inMilliseconds) / _period.inMilliseconds * 2 * math.pi;
  }
}

/// How the sparkle's interior is painted.
enum PregoAiLoaderFillMode() {
  /// Hollow while working; fills once when work finishes.
  keyframed,

  /// A hollow mark, including when a parent owns its animation.
  outline,
}

/// Figma's `Icon AI Loader` (2506:20093): a 14px glyph in a 20px slot.
///
/// [animate] means the agent is working: a hollow sparkle turns once every
/// two seconds. Changing it to false eases the current rotation into place
/// and fills the sparkle blue, once. Mounting an already-unread row renders
/// the solid mark immediately. A new turn interrupts the settle in place.
///
/// Apple platforms keep the loop and settle in Core Animation; other platforms
/// repaint only this isolated primitive. Reduced motion preserves the hollow
/// working / solid unread distinction without rotation. The containing row
/// supplies the status semantics; this mark is decorative.
class const PregoAiLoader({
  super.key,
  final double size = 20,
  final bool animate = true,
  final PregoAiLoaderFillMode fillMode = .keyframed,

  /// Overrides both states, for a caller-owned timeline such as Deep Scan.
  final Color? color,
}) extends StatefulWidget {
  @override
  State<PregoAiLoader> createState() => _PregoAiLoaderState();
}

class _PregoAiLoaderState()
    extends State<PregoAiLoader>
    with TickerProviderStateMixin, WidgetsBindingObserver, PregoReducedMotionStateMixin {
  static const _nativeViewType = "sesori/native-ai-loader";

  // The Figma example contains several seconds of loading and a long idle
  // hold. Only the finish is a UI transition: preserve its fill and rotational
  // overshoot in 700ms, without delaying the actual thread state or input.
  // Keep these values in step with AiLoaderSparkle in the Darwin renderer.
  static const _settleDuration = Duration(milliseconds: 700);
  static const _resumeDuration = Duration(milliseconds: 150);
  static const _settleCurve = Cubic(0.45, 1.45, 0.833, 1.368);

  late final _rotation = AnimationController.unbounded(vsync: this);
  late final _fill = AnimationController(vsync: this, value: 1)..addListener(_updateLoopAngle);
  final _loopClock = _AiLoaderLoopClock.instance;
  double _loopAngle = 0;
  double _loopOffset = 0;
  bool _listeningToLoop = false;
  late ({Color fill, Color stroke}) _fillOrigin = (
    fill: const Color(0x00B2D1FF),
    stroke: context.prego.colors.textPrimary,
  );
  MethodChannel? _nativeChannel;

  bool get _usesNativeRenderer =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) &&
      widget.fillMode == .keyframed &&
      widget.color == null;

  bool get _appIsVisible {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed || lifecycle == AppLifecycleState.inactive;
  }

  @override
  bool get motionEnabled => !_usesNativeRenderer && TickerMode.valuesOf(context).enabled && _appIsVisible;

  @override
  void startMotion() {
    if (widget.animate) {
      _startLoop(rejoin: _fill.value < 1);
    } else {
      _stopLoop();
      if (_fill.value < 1 && !_rotation.isAnimating) {
        const quarterTurn = math.pi / 2;
        final target = ((_rotation.value + 0.593) / quarterTurn).ceil() * quarterTurn;
        _rotation.animateTo(target, duration: _settleDuration, curve: _settleCurve);
      }
    }
    if (_fill.value < 1 && !_fill.isAnimating) {
      _fill.animateTo(1, duration: widget.animate ? _resumeDuration : _settleDuration);
    }
  }

  @override
  void stopMotion() {
    _stopLoop();
    _rotation.stop();
    _rotation.value = 0;
    _fill.stop();
    _fill.value = 1;
  }

  void _startLoop({required bool rejoin}) {
    if (_listeningToLoop) return;
    _listeningToLoop = true;
    _loopClock.addListener(_updateLoopAngle);
    final phaseAngle = _loopClock.angle;
    _loopAngle = phaseAngle + ((_rotation.value - phaseAngle) / (2 * math.pi)).round() * 2 * math.pi;
    _loopOffset = rejoin ? _rotation.value - _loopAngle : 0;
    _updateLoopAngle();
  }

  void _stopLoop() {
    if (!_listeningToLoop) return;
    _loopClock.removeListener(_updateLoopAngle);
    _listeningToLoop = false;
  }

  void _updateLoopAngle() {
    if (!_listeningToLoop) return;
    final phaseAngle = _loopClock.angle;
    _loopAngle = phaseAngle + ((_loopAngle - phaseAngle) / (2 * math.pi)).round() * 2 * math.pi;
    _rotation.value = _loopAngle + _loopOffset * (1 - _fill.value);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    syncMotion();
  }

  @override
  void didUpdateWidget(PregoAiLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) {
      // Capture colours as well as rotation. Reversing the finishing timeline
      // would flash the pale-blue highlight again when a new turn starts.
      final colors = context.prego.colors;
      _fillOrigin = _AiLoaderPainter.colorsAt(
        progress: _fill.value,
        loading: oldWidget.animate,
        origin: _fillOrigin,
        solid: widget.color ?? colors.textPrimaryOnBrand,
        outline: widget.color ?? colors.textPrimary,
        bloom: widget.color ?? const Color(0xFFB2D1FF),
      );
      _stopLoop();
      _rotation.stop();
      _fill.stop();
      _fill.value = 0;
      syncMotion();
      if (_usesNativeRenderer && !prefersReducedMotion(context) && TickerMode.valuesOf(context).enabled) {
        unawaited(_updateNativeLoading());
      }
    } else if (oldWidget.fillMode != widget.fillMode || oldWidget.color != widget.color) {
      stopMotion();
      syncMotion();
    }
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, platform-view callback signature
  void _nativeViewCreated(int id) {
    _nativeChannel = MethodChannel("$_nativeViewType/$id");
    // The row may have finished while the platform was creating its view.
    unawaited(_updateNativeLoading());
  }

  Future<void> _updateNativeLoading() async {
    try {
      await _nativeChannel?.invokeMethod<void>("setLoading", widget.animate);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: "theme_prego",
          context: ErrorDescription("updating native AI loader state"),
        ),
      );
    }
  }

  @override
  void dispose() {
    _stopLoop();
    _rotation.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    final native = _usesNativeRenderer && !prefersReducedMotion(context) && TickerMode.valuesOf(context).enabled;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: native
            ? _nativeSparkle(colors: colors)
            : CustomPaint(
                size: Size.square(widget.size),
                painter: _AiLoaderPainter(
                  rotation: _rotation,
                  fill: _fill,
                  loading: widget.animate,
                  origin: _fillOrigin,
                  fillMode: widget.fillMode,
                  solid: widget.color ?? colors.textPrimaryOnBrand,
                  outline: widget.color ?? colors.textPrimary,
                  bloom: widget.color ?? const Color(0xFFB2D1FF),
                ),
              ),
      ),
    );
  }

  Widget _nativeSparkle({required PregoColors colors}) {
    // StandardMessageCodec carries ARGB integers and a bool.
    // ignore: no_slop_linter/prefer_specific_type, heterogeneous native codec payload
    final params = <String, Object>{
      "solid": colors.textPrimaryOnBrand.toARGB32(),
      "outline": colors.textPrimary.toARGB32(),
      "loading": widget.animate,
    };
    final nativeView = defaultTargetPlatform == TargetPlatform.iOS
        ? UiKitView(
            viewType: _nativeViewType,
            creationParams: params,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _nativeViewCreated,
            hitTestBehavior: PlatformViewHitTestBehavior.transparent,
          )
        : AppKitView(
            viewType: _nativeViewType,
            creationParams: params,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _nativeViewCreated,
            hitTestBehavior: PlatformViewHitTestBehavior.transparent,
          );
    return SizedBox.square(
      dimension: widget.size,
      // State must not replace the renderer at completion. Colours
      // are creation-time data, so a theme change does create the new palette.
      child: KeyedSubtree(
        key: ValueKey(Object.hash(params["solid"], params["outline"])),
        child: nativeView,
      ),
    );
  }
}

/// Paint-only animation: neither the row nor this widget rebuilds per frame.
class _AiLoaderPainter({
  required final Animation<double> rotation,
  required final Animation<double> fill,
  required final bool loading,
  required final ({Color fill, Color stroke}) origin,
  required final PregoAiLoaderFillMode fillMode,
  required final Color solid,
  required final Color outline,
  required final Color bloom,
}) extends CustomPainter {
  this : super(repaint: Listenable.merge([rotation, fill]));

  // The existing Tabler sparkle-2 centreline matches the Figma font glyph.
  // Fill + stroke preserves the same outer silhouette in both states.
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

  static ({Color fill, Color stroke}) colorsAt({
    required double progress,
    required bool loading,
    required ({Color fill, Color stroke}) origin,
    required Color solid,
    required Color outline,
    required Color bloom,
  }) {
    const ease = Cubic(0.5, 0, 0.5, 1);
    final t = ease.transform(progress);
    if (loading) {
      return (
        fill: lerpColorNonNull(origin.fill, bloom.withValues(alpha: 0), t),
        stroke: lerpColorNonNull(origin.stroke, outline, t),
      );
    }
    return (
      fill: progress < 0.5
          ? lerpColorNonNull(origin.fill, bloom, ease.transform(progress * 2))
          : lerpColorNonNull(bloom, solid, ease.transform((progress - 0.5) * 2)),
      stroke: lerpColorNonNull(origin.stroke, solid, t),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final colors = fillMode == .outline
        ? (fill: outline.withValues(alpha: 0), stroke: outline)
        : colorsAt(
            progress: fill.value,
            loading: loading,
            origin: origin,
            solid: solid,
            outline: outline,
            bloom: bloom,
          );

    canvas.save();
    canvas.scale(size.shortestSide / 20);
    canvas.translate(10, 10.4);
    canvas.rotate(rotation.value);
    canvas.translate(-10, -10.4);
    // Figma uses a 14px Tabler font in a 20px line box. The exported glyph's
    // baseline puts its centre at (10, 10.4), rather than (10, 10).
    canvas.translate(3, 3.4);
    canvas.scale(14 / 24);
    canvas.drawPath(_sparkle, Paint()..color = colors.fill);
    canvas.drawPath(
      _sparkle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = colors.stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AiLoaderPainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.fill != fill ||
      oldDelegate.loading != loading ||
      oldDelegate.origin != origin ||
      oldDelegate.fillMode != fillMode ||
      oldDelegate.solid != solid ||
      oldDelegate.outline != outline ||
      oldDelegate.bloom != bloom;
}
