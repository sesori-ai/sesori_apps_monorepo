import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// A soft halo that breathes behind the composer mic while it listens.
///
/// Painted only, never laid out: the halo grows past [child]'s bounds without
/// moving anything around it. It fades in and out with [active], and holds
/// still under reduced motion.
class const ComposerListeningPulse({
  super.key,
  required final bool active,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<ComposerListeningPulse> createState() => _ComposerListeningPulseState();
}

class _ComposerListeningPulseState() extends State<ComposerListeningPulse>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, PregoReducedMotionStateMixin {
  static const _period = Duration(milliseconds: 1400);
  static const _fadeDuration = Duration(milliseconds: 220);
  static const _maxGrowth = 0.3;

  late final AnimationController _controller = AnimationController(vsync: this, duration: _period);

  @override
  bool get motionEnabled => widget.active;

  @override
  void startMotion() {
    if (!_controller.isAnimating) _controller.repeat();
  }

  @override
  void stopMotion() => _controller.stop();

  @override
  void didUpdateWidget(ComposerListeningPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) syncMotion();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.prego.colors.textPrimary;
    final reducedMotion = prefersReducedMotion(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: widget.active ? 1 : 0,
              duration: _fadeDuration,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  // Reduced motion rests on a still mid-size ring.
                  final phase = reducedMotion ? 0.5 : _controller.value;
                  return Transform.scale(
                    scale: 1 + _maxGrowth * phase,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.22 * (1 - phase)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
