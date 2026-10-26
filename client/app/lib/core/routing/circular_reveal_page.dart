import "dart:math" as math;

import "package:flutter/gestures.dart";
import "package:flutter/physics.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";

/// How long the circle takes to cover the screen, and to shrink back.
const Duration _revealDuration = Duration(milliseconds: 400);
const Curve _revealCurve = Curves.easeInOutCubic;

/// The start-edge strip that catches an iOS back swipe, as wide as the
/// platform's own.
const double _backSwipeEdgeWidth = 20;

/// A release faster than this, in page widths per second, decides by its
/// direction instead of by how far the swipe went.
const double _backSwipeFlingVelocity = 1;

/// Carries a released swipe's speed to its end. Critically damped, it settles
/// without bouncing; its goal lies just past the end it settles on, so it
/// finishes as it gets there instead of creeping up on it.
final SpringDescription _settleSpring = SpringDescription.withDampingRatio(mass: 1, stiffness: 200);
const Tolerance _settleTolerance = Tolerance(distance: 0.01, velocity: double.infinity);

/// A page that opens as a circle growing from [origin] until it covers the
/// screen, while the page below holds still, and leaves by shrinking back into
/// it. On iOS a swipe from the start edge scrubs the circle back and, released,
/// settles open or closed with the swipe's speed.
///
/// Beside the sidebar and under reduced motion there is no circle: it moves as
/// [fallbackTransitionsBuilder] does instead.
class const CircularRevealPage({
  required super.key,

  /// The circle's centre as fractions of the page's size, so it stays on the
  /// same spot across a rotation.
  required final FractionalOffset origin,
  required final RouteTransitionsBuilder fallbackTransitionsBuilder,
  required final Widget child,
}) extends Page<void> {
  @override
  Route<void> createRoute(BuildContext context) => _CircularRevealRoute(
    settings: this,
    // Read once, as a page's transition duration is.
    transitionDuration: context.isReducedMotion ? Duration.zero : _revealDuration,
  );
}

class _CircularRevealRoute({required super.settings, @override required final Duration transitionDuration})
    extends PageRoute<void> {
  CircularRevealPage get _page => switch (settings) {
    final CircularRevealPage page => page,
    _ => throw StateError("A circular reveal route shows a CircularRevealPage"),
  };

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  /// The page below holds still while the circle grows over it.
  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return Semantics(scopesRoute: true, explicitChildNodes: true, child: _page.child);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (SessionSidebarShell.layoutOf(context) == SessionShellLayout.pane || context.isReducedMotion) {
      return _page.fallbackTransitionsBuilder(context, animation, secondaryAnimation, child);
    }
    final swipesBack = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      TargetPlatform.android || TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.windows => false,
    };
    return _BackSwipeDetector(
      enabled: () => swipesBack && popGestureEnabled,
      onStart: _startBackSwipe,
      child: _CircularRevealTransition(
        // A swipe moves the circle with the finger.
        progress: popGestureInProgress ? animation : animation.drive(CurveTween(curve: _revealCurve)),
        origin: _page.origin,
        child: child,
      ),
    );
  }

  _BackSwipe _startBackSwipe() {
    final controller = this.controller;
    final navigator = this.navigator;
    if (controller == null || navigator == null) throw StateError("Only an installed route swipes back");
    navigator.didStartUserGesture();
    return _BackSwipe(route: this, controller: controller, navigator: navigator);
  }
}

/// One back swipe driving its route's animation, from fully open (1) to gone
/// (0).
class const _BackSwipe({
  required final PageRoute<void> route,
  required final AnimationController controller,
  required final NavigatorState navigator,
}) {
  /// [delta] is the finger's move toward the end edge, in page widths.
  void update({required double delta}) => controller.value -= delta;

  /// [velocity] is the release speed toward the end edge, in page widths per
  /// second.
  void end({required double velocity}) {
    final bool closes;
    if (!route.isCurrent) {
      // Navigation during the swipe decided already: settle as it left the
      // route.
      closes = !route.isActive;
    } else if (velocity.abs() >= _backSwipeFlingVelocity) {
      closes = velocity > 0;
    } else {
      closes = controller.value < 0.5;
    }
    final simulation = SpringSimulation(
      _settleSpring,
      controller.value,
      closes ? controller.lowerBound - _settleTolerance.distance : controller.upperBound + _settleTolerance.distance,
      -velocity,
      tolerance: _settleTolerance,
    );
    if (closes) {
      if (route.isCurrent) navigator.pop();
      // A swipe all the way across has nothing left to settle.
      if (controller.isAnimating) controller.animateBackWith(simulation);
    } else {
      controller.animateWith(simulation);
    }
    if (!controller.isAnimating) return navigator.didStopUserGesture();
    // The circle follows the spring rather than the curve until it settles.
    late final AnimationStatusListener settled;
    settled = (status) {
      if (status.isAnimating) return;
      controller.removeStatusListener(settled);
      navigator.didStopUserGesture();
    };
    controller.addStatusListener(settled);
  }
}

/// Starts a [_BackSwipe] from a horizontal drag that begins on the page's
/// start edge.
class const _BackSwipeDetector({
  required final ValueGetter<bool> enabled,
  required final ValueGetter<_BackSwipe> onStart,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<_BackSwipeDetector> createState() => _BackSwipeDetectorState();
}

class _BackSwipeDetectorState() extends State<_BackSwipeDetector> {
  late final HorizontalDragGestureRecognizer _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
    ..onStart = _handleStart
    ..onUpdate = _handleUpdate
    ..onEnd = _handleEnd
    ..onCancel = _handleCancel;
  _BackSwipe? _swipe;

  @override
  void dispose() {
    _recognizer.dispose();
    // A page removed mid-swipe still releases the navigator, whose routes
    // ignore touches while a swipe is in progress.
    if (_swipe case final swipe?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (swipe.navigator.mounted) swipe.navigator.didStopUserGesture();
      });
    }
    super.dispose();
  }

  void _handleStart(DragStartDetails details) => _swipe = widget.onStart();

  void _handleUpdate(DragUpdateDetails details) {
    _swipe?.update(delta: _pageWidths(details.primaryDelta ?? 0));
  }

  void _handleEnd(DragEndDetails details) {
    _swipe?.end(velocity: _pageWidths(details.velocity.pixelsPerSecond.dx));
    _swipe = null;
  }

  void _handleCancel() {
    _swipe?.end(velocity: 0);
    _swipe = null;
  }

  /// [pixels] toward the end edge, in page widths.
  double _pageWidths(double pixels) {
    final width = context.size?.width ?? (throw StateError("A swiped page is laid out"));
    return switch (Directionality.of(context)) {
      TextDirection.ltr => pixels / width,
      TextDirection.rtl => -pixels / width,
    };
  }

  @override
  Widget build(BuildContext context) {
    // A notch on the start edge widens the strip past it.
    final notch = switch (Directionality.of(context)) {
      TextDirection.ltr => MediaQuery.paddingOf(context).left,
      TextDirection.rtl => MediaQuery.paddingOf(context).right,
    };
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          width: math.max(notch, _backSwipeEdgeWidth),
          top: 0,
          bottom: 0,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) {
              if (widget.enabled()) _recognizer.addPointer(event);
            },
          ),
        ),
      ],
    );
  }
}

/// How the circle lifts off the page below it, at its peak: the page
/// dims and the circle's rim casts a soft shadow onto it. A shadow alone
/// barely shows on a dark page, so there the page dims further and the circle
/// lightens, as a raised dark surface does.
class const _RevealLift({
  /// The black over the page below once the circle covers it.
  required final double dimAlpha,
  required final double shadowAlpha,
  required final double shadowBlur,
  required final double shadowOffsetY,

  /// The white over the circle; 0 for none.
  required final double tintAlpha,
});

const _lightLift = _RevealLift(dimAlpha: 0.112, shadowAlpha: 0.308, shadowBlur: 14, shadowOffsetY: 2, tintAlpha: 0);
const _darkLift = _RevealLift(dimAlpha: 0.56, shadowAlpha: 1, shadowBlur: 22, shadowOffsetY: 0, tintAlpha: 0.07);

/// Clips [child] to a circle around [origin] whose radius runs with
/// [progress], from nothing to the page's farthest corner, and lifts the
/// circle off the page below as it grows.
class const _CircularRevealTransition({
  required final Animation<double> progress,
  required final FractionalOffset origin,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lift = context.isDarkMode ? _darkLift : _lightLift;
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final value = progress.value;
        // Fully open, the page paints unclipped and alone.
        final open = value >= 1;
        return CustomPaint(
          painter: open ? null : _UnderCirclePainter(lift: lift, origin: origin, progress: value),
          foregroundPainter: open || lift.tintAlpha == 0
              ? null
              : _OverCirclePainter(lift: lift, origin: origin, progress: value),
          child: ClipPath(
            clipper: _CircleClipper(origin: origin, progress: value),
            clipBehavior: open ? Clip.none : Clip.antiAlias,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Under the circle: the page below dims as the circle grows, and the rim
/// casts its shadow. The shadow grows in over the first 8%, so it never starts
/// as a dot, and leaves over the last 30%, so nothing pops when the clip ends.
class const _UnderCirclePainter({
  required final _RevealLift lift,
  required final FractionalOffset origin,
  required final double progress,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dim = lift.dimAlpha * Curves.easeOut.transform(progress);
    canvas.drawRect(Offset.zero & size, Paint()..color = Color.from(alpha: dim, red: 0, green: 0, blue: 0));
    final shadow =
        lift.shadowAlpha *
        const Interval(0, 0.08).transform(progress) *
        (1 - const Interval(0.7, 1, curve: Curves.easeIn).transform(progress));
    final circle = _circleAt(size: size, origin: origin, progress: progress);
    canvas.drawCircle(
      circle.centre.translate(0, lift.shadowOffsetY),
      circle.radius,
      Paint()
        ..color = Color.from(alpha: shadow, red: 0, green: 0, blue: 0)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, lift.shadowBlur),
    );
  }

  /// Touches outside the circle go on below, as they would without it.
  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_UnderCirclePainter oldDelegate) =>
      oldDelegate.lift != lift || oldDelegate.origin != origin || oldDelegate.progress != progress;
}

/// Over the circle: its lightening tint. By the end it covers most of the
/// screen, so it leaves gradually over the second half.
class const _OverCirclePainter({
  required final _RevealLift lift,
  required final FractionalOffset origin,
  required final double progress,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tint =
        lift.tintAlpha *
        const Interval(0, 0.08).transform(progress) *
        (1 - const Interval(0.5, 1, curve: Curves.easeInOut).transform(progress));
    final circle = _circleAt(size: size, origin: origin, progress: progress);
    canvas.drawCircle(
      circle.centre,
      circle.radius,
      Paint()..color = Color.from(alpha: tint, red: 1, green: 1, blue: 1),
    );
  }

  @override
  bool shouldRepaint(_OverCirclePainter oldDelegate) =>
      oldDelegate.lift != lift || oldDelegate.origin != origin || oldDelegate.progress != progress;
}

/// The circle's centre and radius at [progress] on a page of [size].
({Offset centre, double radius}) _circleAt({
  required Size size,
  required FractionalOffset origin,
  required double progress,
}) {
  final centre = origin.alongSize(size);
  final farthestCorner = [
    size.topLeft(Offset.zero),
    size.topRight(Offset.zero),
    size.bottomLeft(Offset.zero),
    size.bottomRight(Offset.zero),
  ].map((corner) => (corner - centre).distance).reduce(math.max);
  return (centre: centre, radius: farthestCorner * progress);
}

class const _CircleClipper({required final FractionalOffset origin, required final double progress})
    extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    // Fully open, every point of the page takes touches, corners included.
    if (progress >= 1) return Path()..addRect(Offset.zero & size);
    final circle = _circleAt(size: size, origin: origin, progress: progress);
    return Path()..addOval(Rect.fromCircle(center: circle.centre, radius: circle.radius));
  }

  @override
  bool shouldReclip(_CircleClipper oldClipper) => oldClipper.origin != origin || oldClipper.progress != progress;
}
