import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:universal_platform/universal_platform.dart";

import "../theme/zyra_theme.dart";

void tapUpFeedback() => HapticFeedback.lightImpact();
void tapDownFeedback() => HapticFeedback.selectionClick();

// ---------------------------------------------------------------------------
// Builder sealed hierarchy
// ---------------------------------------------------------------------------

/// Mutually exclusive builder modes for [ZyraTappable].
///
/// [_SimpleBuilders]: default constructor — static child, interaction handled via overlay.
/// [_StateAwareBuilders]: `.stateAware` constructor — builders receive interaction state set.
sealed class _TappableBuilders {
  const _TappableBuilders();
}

final class _SimpleBuilders extends _TappableBuilders {
  const _SimpleBuilders({required this.child, required this.containerBuilder});
  final Widget child;
  final Widget Function(Widget child) containerBuilder;
}

final class _StateAwareBuilders extends _TappableBuilders {
  const _StateAwareBuilders({required this.childBuilder, required this.containerBuilder});
  final Widget Function({required Set<WidgetState> state}) childBuilder;
  final Widget Function({required Widget child, required Set<WidgetState> state}) containerBuilder;
}

// ---------------------------------------------------------------------------
// ZyraTappable
// ---------------------------------------------------------------------------

/// Platform-aware interaction wrapper for tappable elements.
///
/// Routes to platform-specific implementations:
/// - Web: instant press/hover overlays, no animation
/// - iOS: scale overshoot -> settle -> release with shadow interpolation
/// - Android: Material [InkWell] ripple
///
/// Takes a [containerBuilder] and [child] (content) separately. The wrapping
/// order is flipped per platform:
/// - **iOS/Web**: interaction → container → content (scale lifts the whole container)
/// - **Android**: container → interaction → content (ripple above bg, below content)
///
/// Pass `onTap: null` to disable interaction (renders `containerBuilder(child)`).
///
/// Use [ZyraTappable.stateAware] when the component needs to control its own
/// interaction styling (e.g. background colour changes on hover, underline, etc.)
/// instead of relying on the default overlay.
class ZyraTappable extends StatelessWidget {
  /// **Constraint rule**: [containerBuilder] must pass tight constraints through
  /// to [child]. Never use [Center]/[Align] inside [containerBuilder] — they
  /// loosen constraints and break the hit area. Apply alignment as part of
  /// the [child] builder instead.
  ZyraTappable({
    super.key,
    required Widget child,
    required this.onTap,
    required Widget Function(Widget child) containerBuilder,
    this.overlayColor,
    required this.borderRadius,
    this.useSuperellipse = false,
    this.overlayInset = 0.0,
  }) : _builders = _SimpleBuilders(
         child: child,
         containerBuilder: containerBuilder,
       );

  /// State-aware variant — builders receive a `Set<WidgetState>` so the
  /// component can apply its own interaction styling (bg colour changes on hover,
  /// underline, etc.) instead of relying on the default overlay.
  ZyraTappable.stateAware({
    super.key,
    required Widget Function({required Set<WidgetState> state}) childBuilder,
    required Widget Function({required Widget child, required Set<WidgetState> state}) containerBuilder,
    required this.onTap,
    this.overlayColor,
    required this.borderRadius,
    this.useSuperellipse = false,
    this.overlayInset = 0.0,
  }) : _builders = _StateAwareBuilders(
         childBuilder: childBuilder,
         containerBuilder: containerBuilder,
       );

  final _TappableBuilders _builders;

  /// Called when the user taps the element. Pass `null` to disable interaction.
  final VoidCallback? onTap;

  /// State-dependent overlay color resolved against the current interaction states.
  /// Defaults to [ThemeData.splashColor] for [WidgetState.pressed], half-alpha for
  /// [WidgetState.hovered], and `null` (no overlay) otherwise.
  final WidgetStateProperty<Color?>? overlayColor;

  /// Border radius for clipping overlays and shaping shadows.
  final BorderRadius borderRadius;

  /// When `true`, uses [RoundedSuperellipseBorder] instead of [BorderRadius]
  /// for clipping, ripple bounds, shadows and overlay shapes.
  final bool useSuperellipse;

  /// When non-zero, the press/hover overlay is inset by this amount on every
  /// side, preventing it from painting over the component's border.
  /// Set this to your border width to restrict the overlay to the background fill.
  final double overlayInset;

  @override
  Widget build(BuildContext context) {
    // Can hardcode value to test different platform interactions.
    final UniversalPlatformType platform = UniversalPlatform.value;

    // Unwrap sealed builders into unified types.
    final Widget Function({required Set<WidgetState> state}) childBuilder;
    final Widget Function({required Widget child, required Set<WidgetState> state}) containerBuilder;
    switch (_builders) {
      case _SimpleBuilders(:final child, containerBuilder: final cb):
        childBuilder = ({required Set<WidgetState> state}) => child;
        containerBuilder = ({required Widget child, required Set<WidgetState> state}) => cb(child);
      case _StateAwareBuilders(childBuilder: final cb, containerBuilder: final ccb):
        childBuilder = cb;
        containerBuilder = ccb;
    }

    final onTap = this.onTap;
    if (onTap == null) {
      return containerBuilder(
        state: const {WidgetState.disabled},
        child: childBuilder(state: const {WidgetState.disabled}),
      );
    }

    final resolvedOverlayColor =
        overlayColor ??
        WidgetStateProperty.resolveWith<Color?>((states) {
          final splashColor = Theme.of(context).splashColor;
          if (states.contains(WidgetState.pressed)) return splashColor;
          if (states.contains(WidgetState.hovered)) return splashColor.withValues(alpha: splashColor.a * 0.5);
          return null;
        });

    // iOS/Web: interaction wraps container wraps content.
    // Android: container wraps interaction wraps content.
    return switch (platform) {
      .Web || .Windows || .Linux || .MacOS => _WebTappable(
        onTap: onTap,
        overlayColor: resolvedOverlayColor,
        borderRadius: borderRadius,
        useSuperellipse: useSuperellipse,
        overlayInset: overlayInset,
        childBuilder: childBuilder,
        containerBuilder: containerBuilder,
      ),
      .IOS => _IosTappable(
        onTap: onTap,
        containerBuilder: containerBuilder,
        overlayColor: resolvedOverlayColor,
        borderRadius: borderRadius,
        useSuperellipse: useSuperellipse,
        overlayInset: overlayInset,
        childBuilder: childBuilder,
      ),
      .Android || .Fuchsia => _AndroidTappable(
        onTap: onTap,
        color: resolvedOverlayColor,
        borderRadius: borderRadius,
        useSuperellipse: useSuperellipse,
        overlayInset: overlayInset,
        childBuilder: childBuilder,
        containerBuilder: containerBuilder,
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// Android
// ---------------------------------------------------------------------------

class _AndroidTappable extends StatefulWidget {
  const _AndroidTappable({
    required this.childBuilder,
    required this.containerBuilder,
    required this.onTap,
    required this.color,
    required this.borderRadius,
    required this.useSuperellipse,
    required this.overlayInset,
  });

  final Widget Function({required Set<WidgetState> state}) childBuilder;
  final Widget Function({required Widget child, required Set<WidgetState> state}) containerBuilder;
  final VoidCallback onTap;
  final WidgetStateProperty<Color?> color;
  final BorderRadius borderRadius;
  final bool useSuperellipse;
  final double overlayInset;

  @override
  State<_AndroidTappable> createState() => _AndroidTappableState();
}

class _AndroidTappableState extends State<_AndroidTappable> {
  final Set<WidgetState> _state = {};

  BorderRadius _rippleBorderRadius = .zero;
  Color _splashAndHighlightOverlayColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _updateRippleBorderRadius();
    _updateSplashAndHighlightOverlayColor();
  }

  @override
  void didUpdateWidget(_AndroidTappable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.borderRadius != widget.borderRadius || oldWidget.overlayInset != widget.overlayInset) {
      _updateRippleBorderRadius();
    }
    if (oldWidget.color != widget.color) {
      _updateSplashAndHighlightOverlayColor();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The content renders at full size. The Material+InkWell sits in a separate
    // inset Positioned layer with no content of its own, so the ripple is
    // confined inside the border without affecting the content's layout.
    final content = Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned(
          left: widget.overlayInset,
          right: widget.overlayInset,
          top: widget.overlayInset,
          bottom: widget.overlayInset,
          child: Material(
            type: .transparency,
            child: InkWell(
              borderRadius: widget.useSuperellipse ? null : _rippleBorderRadius,
              customBorder: widget.useSuperellipse
                  ? RoundedSuperellipseBorder(borderRadius: _rippleBorderRadius)
                  : null,
              splashColor: _splashAndHighlightOverlayColor,
              highlightColor: _splashAndHighlightOverlayColor,
              // onHighlightChanged: (highlighted) => setState(() => highlighted ? _state.add(WidgetState.hovered) : _state.remove(WidgetState.hovered)),
              onTap: () {
                setState(() => _state.remove(WidgetState.pressed));
                tapUpFeedback();
                widget.onTap();
              },
              onTapDown: (_) => setState(() => _state.add(WidgetState.pressed)),
              onTapCancel: () => setState(() => _state.remove(WidgetState.pressed)),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        IgnorePointer(child: widget.childBuilder(state: _state)),
      ],
    );

    return widget.containerBuilder(
      child: content,
      state: _state,
    );
  }

  void _updateRippleBorderRadius() {
    _rippleBorderRadius = _insetBorderRadius(widget.borderRadius, widget.overlayInset);
  }

  void _updateSplashAndHighlightOverlayColor() {
    final color = widget.color.resolve(const {WidgetState.pressed});
    _splashAndHighlightOverlayColor = color?.withValues(alpha: color.a * 0.5) ?? Colors.transparent;
  }
}

// ---------------------------------------------------------------------------
// Web
// ---------------------------------------------------------------------------

class _WebTappable extends StatefulWidget {
  const _WebTappable({
    required this.childBuilder,
    required this.containerBuilder,
    required this.onTap,
    required this.overlayColor,
    required this.borderRadius,
    required this.useSuperellipse,
    required this.overlayInset,
  });

  final Widget Function({required Set<WidgetState> state}) childBuilder;
  final Widget Function({required Widget child, required Set<WidgetState> state}) containerBuilder;
  final VoidCallback onTap;
  final WidgetStateProperty<Color?> overlayColor;
  final BorderRadius borderRadius;
  final bool useSuperellipse;
  final double overlayInset;

  @override
  State<_WebTappable> createState() => _WebTappableState();
}

class _WebTappableState extends State<_WebTappable> {
  static const _minFeedbackDuration = Duration(milliseconds: 150);

  bool _isPressed = false;
  bool _isHovered = false;
  DateTime _tapDownAt = DateTime(0);
  Timer? _feedbackTimer;

  /// Border radius for the overlay, used to align it with the inner edge of the border when
  /// [ZyraTappable.overlayInset] is set. Will be set in [initState] and [didUpdateWidget].
  BorderRadius _overlayBorderRadius = .zero;

  @override
  void initState() {
    super.initState();
    _overlayBorderRadius = _insetBorderRadius(widget.borderRadius, widget.overlayInset);
  }

  @override
  void didUpdateWidget(_WebTappable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.borderRadius != widget.borderRadius || oldWidget.overlayInset != widget.overlayInset) {
      _overlayBorderRadius = _insetBorderRadius(widget.borderRadius, widget.overlayInset);
    }
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _handleTapDown() {
    _feedbackTimer?.cancel();
    _tapDownAt = DateTime.now();
    setState(() => _isPressed = true);
  }

  void _handleTapUp() {
    widget.onTap();
    final elapsed = DateTime.now().difference(_tapDownAt);
    final remaining = _minFeedbackDuration - elapsed;
    if (remaining > Duration.zero) {
      _feedbackTimer = Timer(remaining, () {
        if (mounted) setState(() => _isPressed = false);
      });
    } else {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    _feedbackTimer?.cancel();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = <WidgetState>{
      if (_isPressed) WidgetState.pressed,
      if (_isHovered) WidgetState.hovered,
    };
    final overlayColor = widget.overlayColor.resolve(state);

    final content = widget.childBuilder(state: state);

    // Overlay sits between background and content (not on top of the entire element).
    final Widget effectiveContent;
    if (overlayColor != null) {
      effectiveContent = Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: widget.overlayInset,
            right: widget.overlayInset,
            top: widget.overlayInset,
            bottom: widget.overlayInset,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: _shapeDecoration(
                  borderRadius: _overlayBorderRadius,
                  useSuperellipse: widget.useSuperellipse,
                  color: overlayColor,
                ),
              ),
            ),
          ),
          content,
        ],
      );
    } else {
      effectiveContent = content;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _handleTapDown(),
        onTapUp: (_) => _handleTapUp(),
        onTapCancel: _handleTapCancel,
        child: widget.containerBuilder(child: effectiveContent, state: state),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// iOS
// ---------------------------------------------------------------------------

/// Cubic easeOutBack curve parameterised by its peak output value.
///
/// The curve travels from 0 → [peak] → 1.0, producing an overshoot-then-settle
/// shape. For example, `peak: 1.25` means the output briefly reaches 1.25
/// (25% beyond the target) before settling at 1.0.
///
/// Internally converts [peak] to the easeOutBack tension parameter _s_ via
/// Newton's method on: `peak = 1 + 4s³ / (27(s+1)²)`.
class _OvershootCurve extends Curve {
  _OvershootCurve({required double peak}) : assert(peak > 1.0, 'peak must be > 1.0 for overshoot'), _s = _solveS(peak);

  final double _s;

  /// Solves for the easeOutBack tension parameter that produces [peak].
  static double _solveS(double peak) {
    final target = peak - 1.0;
    // Initial guess from large-s approximation: target ≈ 4s/27.
    var s = (target * 6.75).clamp(0.5, double.infinity);
    for (var i = 0; i < 8; i++) {
      final s1 = s + 1.0;
      final f = 4.0 * s * s * s / (27.0 * s1 * s1) - target;
      final df = 4.0 * s * s * (s + 3.0) / (27.0 * s1 * s1 * s1);
      s -= f / df;
    }
    return s;
  }

  @override
  double transformInternal(double t) {
    // ignore: parameter_assignments
    t -= 1.0;
    return t * t * ((_s + 1) * t + _s) + 1.0;
  }
}

/// Reusable scale-pulse animation logic for iOS-style press interactions.
///
/// Manages an [AnimationController] that drives an overshoot scale animation on press,
/// guarantees minimum visible feedback on quick taps, and reverses on release.
///
/// Requires [isScalePulseActive] to be implemented — used to guard against reversing
/// the animation when the user re-presses during the minimum feedback continuation.
///
/// Exposes [currentScale] and [scaleProgress] for the build method.
mixin _ScalePulseMixin<T extends StatefulWidget> on State<T>, TickerProvider {
  /// Scale factor when the press animation settles. Values > 1.0 scale up
  /// (element grows), values < 1.0 scale down (element shrinks).
  static const _settledScale = 1.09;
  static final _pressCurve = _OvershootCurve(peak: 1.25);
  static const _pressDuration = Duration(milliseconds: 300);
  static const _releaseDuration = Duration(milliseconds: 150);
  static const _minPressFeedbackDuration = Duration(milliseconds: 100);

  /// Derived offset from the identity scale (1.0). Positive for scale-up,
  /// negative for scale-down.
  static const _scaleOffset = _settledScale - 1.0;

  /// Controller driving the scale animation. Accessible for [AnimatedBuilder].
  late final AnimationController scalePulseController;

  /// Whether the element is currently being pressed. Used by [animateRelease]
  /// to guard against reversing if the user re-pressed during the minimum
  /// feedback continuation.
  bool get isScalePulseActive;

  /// Current scale factor: 1.0 at rest, [_settledScale] when pressed.
  double get currentScale => 1.0 + scalePulseController.value * _scaleOffset;

  /// Animation progress normalised to 0–1, clamped. Useful for interpolating
  /// shadows or overlay opacity in sync with the scale pulse. Reaches 1.0 at
  /// the settled point and stays clamped during overshoot.
  double get scaleProgress => scalePulseController.value.clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    scalePulseController = AnimationController(
      vsync: this,
      // Must exceed the curve's peak to allow overshoot values. Does not
      // affect the animation curve, scale, or timing.
      upperBound: 3.0,
    );
  }

  @override
  void dispose() {
    scalePulseController.dispose();
    super.dispose();
  }

  /// Starts the press animation with an overshoot curve.
  void animatePress() {
    scalePulseController.animateTo(1.0, duration: _pressDuration, curve: _pressCurve);
  }

  /// Ensures a visible scale pulse even on very quick taps.
  ///
  /// When the press animation hasn't reached its settling point (controller < 1.0),
  /// the forward overshoot continues briefly before reversing — guaranteeing the
  /// user sees physical feedback regardless of tap speed.
  void animateRelease() {
    if (scalePulseController.value < 1.0) {
      scalePulseController.animateTo(1.0, duration: _minPressFeedbackDuration, curve: _pressCurve).whenComplete(() {
        if (mounted && !isScalePulseActive) {
          scalePulseController.animateTo(0.0, duration: _releaseDuration, curve: Curves.easeOut);
        }
      });
    } else {
      scalePulseController.animateTo(0.0, duration: _releaseDuration, curve: Curves.easeOut);
    }
  }

  /// Cancels the press animation and returns to rest scale.
  void animateCancel() {
    scalePulseController.animateTo(0.0, duration: _releaseDuration, curve: Curves.easeOut);
  }
}

class _IosTappable extends StatefulWidget {
  const _IosTappable({
    required this.childBuilder,
    required this.containerBuilder,
    required this.onTap,
    required this.overlayColor,
    required this.borderRadius,
    required this.useSuperellipse,
    required this.overlayInset,
  });

  final Widget Function({required Set<WidgetState> state}) childBuilder;
  final Widget Function({required Widget child, required Set<WidgetState> state}) containerBuilder;
  final VoidCallback onTap;
  final WidgetStateProperty<Color?> overlayColor;
  final BorderRadius borderRadius;
  final bool useSuperellipse;
  final double overlayInset;

  @override
  State<_IosTappable> createState() => _IosTappableState();
}

class _IosTappableState extends State<_IosTappable>
    with SingleTickerProviderStateMixin, _ScalePulseMixin<_IosTappable> {
  /// Border radius for the overlay, used to align it with the inner edge of the border when
  /// [ZyraTappable.overlayInset] is set. Will be set in [initState] and [didUpdateWidget].
  BorderRadius _overlayBorderRadius = .zero;
  final Set<WidgetState> _state = {};

  @override
  bool get isScalePulseActive => _state.contains(WidgetState.pressed);

  @override
  void initState() {
    super.initState();
    _overlayBorderRadius = _insetBorderRadius(widget.borderRadius, widget.overlayInset);
  }

  @override
  void didUpdateWidget(_IosTappable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.borderRadius != widget.borderRadius || oldWidget.overlayInset != widget.overlayInset) {
      _overlayBorderRadius = _insetBorderRadius(widget.borderRadius, widget.overlayInset);
    }
  }

  void _handleTapDown() {
    setState(() => _state.add(WidgetState.pressed));
    tapDownFeedback();
    animatePress();
  }

  void _handleTapUp() {
    setState(() => _state.remove(WidgetState.pressed));
    tapUpFeedback();
    widget.onTap();
    animateRelease();
  }

  void _handleTapCancel() {
    setState(() => _state.remove(WidgetState.pressed));
    animateCancel();
  }

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: .opaque,
      onTapDown: (_) => _handleTapDown(),
      onTapUp: (_) => _handleTapUp(),
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: scalePulseController,
        builder: (context, _) {
          // Rebuild the container on each frame so that isPressed can drive
          // bg colour changes (e.g. destructive secondary pressed bg).
          // Button content is lightweight (Row + Text + Icon), so the cost
          // of rebuilding during the ~300ms animation is negligible.
          final container = widget.containerBuilder(
            child: widget.childBuilder(state: _state),
            state: _state,
          );

          final pressOverlayColor = widget.overlayColor.resolve(_state);

          return Transform.scale(
            scale: currentScale,
            child: DecoratedBox(
              decoration: _shapeDecoration(
                borderRadius: widget.borderRadius,
                useSuperellipse: widget.useSuperellipse,
                shadows: isDark ? null : _scaledShadows(zyra.shadows.md, scaleProgress),
              ),
              child: Stack(
                fit: StackFit.passthrough,
                clipBehavior: Clip.none,
                children: [
                  container,
                  // Dark mode: progressive foreground lightening instead of shadow.
                  if (isDark && scaleProgress > 0)
                    Positioned(
                      left: widget.overlayInset,
                      right: widget.overlayInset,
                      top: widget.overlayInset,
                      bottom: widget.overlayInset,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: _shapeDecoration(
                            borderRadius: _overlayBorderRadius,
                            useSuperellipse: widget.useSuperellipse,
                            color: Colors.white.withValues(alpha: 0.08 * scaleProgress),
                          ),
                        ),
                      ),
                    ),
                  // Press overlay (shown while finger is down).
                  if (pressOverlayColor != null)
                    Positioned(
                      left: widget.overlayInset,
                      right: widget.overlayInset,
                      top: widget.overlayInset,
                      bottom: widget.overlayInset,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: _shapeDecoration(
                            borderRadius: _overlayBorderRadius,
                            useSuperellipse: widget.useSuperellipse,
                            color: pressOverlayColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // TODO(V2): Pop-out dimming — dim surrounding content by overlaying a semi-transparent
  // layer on the parent, leaving only this tappable un-dimmed. Could be implemented via
  // an Overlay entry or a shared InheritedWidget that coordinates dimming across siblings.
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns a [ShapeDecoration] or [BoxDecoration] depending on [useSuperellipse].
///
/// ignore: no_slop_linter/prefer_required_named_parameters
Decoration _shapeDecoration({
  required BorderRadius borderRadius,
  required bool useSuperellipse,
  Color? color,
  List<BoxShadow>? shadows,
}) {
  if (useSuperellipse) {
    return ShapeDecoration(
      color: color,
      shadows: shadows,
      shape: RoundedSuperellipseBorder(borderRadius: borderRadius),
    );
  }
  return BoxDecoration(
    color: color,
    boxShadow: shadows,
    borderRadius: borderRadius,
  );
}

/// Returns [original] with each radius reduced by [inset], clamped to zero.
///
/// Used to align the overlay shape with the inner edge of the border when
/// [ZyraTappable.overlayInset] is set.
///
/// ignore: no_slop_linter/prefer_required_named_parameters
BorderRadius _insetBorderRadius(BorderRadius original, double inset) {
  if (inset == 0) return original;
  return BorderRadius.only(
    topLeft: Radius.circular((original.topLeft.x - inset).clamp(0.0, double.infinity)),
    topRight: Radius.circular((original.topRight.x - inset).clamp(0.0, double.infinity)),
    bottomLeft: Radius.circular((original.bottomLeft.x - inset).clamp(0.0, double.infinity)),
    bottomRight: Radius.circular((original.bottomRight.x - inset).clamp(0.0, double.infinity)),
  );
}

/// Linearly scales [target] shadow properties by [t] (0 = invisible, 1 = full).
///
/// ignore: no_slop_linter/prefer_required_named_parameters
List<BoxShadow> _scaledShadows(List<BoxShadow> target, double t) {
  if (t <= 0) return const [];
  return target
      .map(
        (s) => BoxShadow(
          color: s.color.withValues(alpha: s.color.a * t),
          offset: s.offset * t,
          blurRadius: s.blurRadius * t,
          spreadRadius: s.spreadRadius * t,
        ),
      )
      .toList();
}
