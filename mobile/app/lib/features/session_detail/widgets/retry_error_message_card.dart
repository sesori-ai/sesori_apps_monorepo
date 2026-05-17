import "package:flutter/material.dart";
import "package:theme_zyra/module_zyra.dart";

/// Inline retry error display for transient provider errors
/// (e.g. "Provider is overloaded").
///
/// Renders as a center-aligned red text row with a subtle shimmer
/// animation to indicate an ongoing loading/retry state.
class RetryErrorMessageCard extends StatefulWidget {
  final String message;

  const RetryErrorMessageCard({
    super.key,
    required this.message,
  });

  @override
  State<RetryErrorMessageCard> createState() => _RetryErrorMessageCardState();
}

class _RetryErrorMessageCardState extends State<RetryErrorMessageCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final shimmerValue = _animation.value;
          // Oscillate opacity between 0.6 and 1.0
          final opacity = 0.6 + (0.4 * shimmerValue);
          // Subtle horizontal shimmer offset
          final shimmerOffset = (shimmerValue - 0.5) * 2; // -1 to 1

          return Center(
            child: ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment(
                    -1.0 + shimmerOffset * 0.5,
                    0.0,
                  ),
                  end: Alignment(
                    1.0 + shimmerOffset * 0.5,
                    0.0,
                  ),
                  colors: [
                    zyra.colors.fgErrorPrimary.withValues(alpha: opacity * 0.5),
                    zyra.colors.fgErrorPrimary.withValues(alpha: opacity),
                    zyra.colors.fgErrorPrimary.withValues(alpha: opacity * 0.5),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: Text(
                widget.message,
                textAlign: TextAlign.center,
                style: zyra.textTheme.textSm.regular.copyWith(
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
