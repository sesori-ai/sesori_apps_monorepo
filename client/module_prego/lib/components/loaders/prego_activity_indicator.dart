import "dart:async";
import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";

/// A Prego activity indicator that animates outside Flutter where supported.
class const PregoActivityIndicator({
  super.key,
  required final Color color,
}) extends StatelessWidget {
  static const _nativeViewType = "sesori/native-activity-indicator";
  static const _defaultDimension = 36.0;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final animationsEnabled = !reducedMotion && TickerMode.valuesOf(context).enabled;

    return Semantics(
      role: SemanticsRole.loadingSpinner,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: _defaultDimension,
            child: animationsEnabled
                ? _animatedIndicator()
                : PregoSteppedActivityIndicator(color: color, animating: false),
          ),
        ),
      ),
    );
  }

  Widget _animatedIndicator() {
    if (kIsWeb) {
      return PregoSteppedActivityIndicator(color: color, animating: true);
    }

    // Android deliberately has no native branch: a hybrid-composition platform
    // view idles Flutter beautifully on a static screen, but wrecks scroll
    // performance wherever a spinner shares the screen with a scrolling list
    // (measured on-device, 2026-08-31), so the stepped Flutter spinner stays.
    final nativeView = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => UiKitView(
        viewType: _nativeViewType,
        creationParams: color.toARGB32(),
        creationParamsCodec: const StandardMessageCodec(),
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
      TargetPlatform.macOS => AppKitView(
        viewType: _nativeViewType,
        creationParams: color.toARGB32(),
        creationParamsCodec: const StandardMessageCodec(),
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
      TargetPlatform.android || TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.windows => null,
    };

    if (nativeView == null) {
      return PregoSteppedActivityIndicator(color: color, animating: true);
    }
    // Native views consume creationParams only at creation, so a colour change
    // (a theme switch while a spinner is visible) must recreate the view.
    return KeyedSubtree(key: ValueKey(color.toARGB32()), child: nativeView);
  }
}

/// The Flutter spinner for platforms without a native renderer: the iOS
/// eight-tick activity indicator, stepped by a plain timer instead of a ticker.
///
/// The indicator's picture only changes when its active tick advances — eight
/// times per second — yet the stock Cupertino widget repaints on every vsync of
/// a continuous animation controller for those same eight pictures, keeping
/// the whole frame pipeline busy at 60-120 Hz. Here each step repaints exactly
/// once and nothing schedules a frame in between, which is the difference
/// between an idle and a continuously rendering app on Android. The timer
/// stops while the app is not visible (paused, hidden, or detached), where a
/// ticker would have been frozen anyway; an inactive-but-visible app (an
/// unfocused desktop window, a system dialog) keeps spinning because the
/// spinner is still on screen. `animating: false` shows one static frame.
class const PregoSteppedActivityIndicator({
  super.key,
  required final Color color,
  required final bool animating,
}) extends StatefulWidget {
  /// Ticks per revolution; one revolution per second matches the stock indicator.
  static const tickCount = 8;
  static const stepDuration = Duration(milliseconds: 1000 ~/ tickCount);

  @override
  State<PregoSteppedActivityIndicator> createState() => _PregoSteppedActivityIndicatorState();
}

class _PregoSteppedActivityIndicatorState() extends State<PregoSteppedActivityIndicator> with WidgetsBindingObserver {
  final _tick = ValueNotifier<int>(0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncTimer();
  }

  @override
  void didUpdateWidget(PregoSteppedActivityIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animating != widget.animating) _syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncTimer();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _tick.dispose();
    super.dispose();
  }

  void _syncTimer() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    // Unknown (not yet reported) counts as visible; inactive is unfocused but
    // still on screen, so only paused/hidden/detached stop the timer.
    final visible =
        lifecycle == null || lifecycle == AppLifecycleState.resumed || lifecycle == AppLifecycleState.inactive;
    final shouldRun = widget.animating && visible;
    if (shouldRun == (_timer != null)) return;
    if (shouldRun) {
      _timer = Timer.periodic(PregoSteppedActivityIndicator.stepDuration, (_) {
        _tick.value = (_tick.value + 1) % PregoSteppedActivityIndicator.tickCount;
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SteppedTickPainter(tick: _tick, color: widget.color),
    );
  }
}

/// Paints the eight ticks. Geometry and alpha ramp mirror Flutter's Cupertino
/// indicator at its default 10 px radius, which is also the size of the native
/// medium spinner used on iOS, so the fallback and the native branch look alike.
class _SteppedTickPainter({
  required ValueListenable<int> tick,
  required final Color color,
}) extends CustomPainter {
  this : super(repaint: tick);

  final ValueListenable<int> tick = tick;

  static const _radius = 10.0;
  static const _alphas = [47, 47, 47, 47, 72, 97, 122, 147];
  static const _tickShape = RRect.fromLTRBXY(
    -_radius / 10,
    -_radius / 3,
    _radius / 10,
    -_radius,
    _radius / 10,
    _radius / 10,
  );

  @override
  void paint(Canvas canvas, Size size) {
    const tickCount = PregoSteppedActivityIndicator.tickCount;
    final paint = Paint();
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2);
    for (var i = 0; i < tickCount; i++) {
      paint.color = color.withAlpha(_alphas[(i - tick.value) % tickCount]);
      canvas
        ..drawRRect(_tickShape, paint)
        ..rotate(2 * math.pi / tickCount);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SteppedTickPainter oldDelegate) => oldDelegate.tick != tick || oldDelegate.color != color;
}
