import "package:flutter/material.dart";

import "../../interactions/prego_tappable.dart";
import "../../theme/prego_theme.dart";
import "../../utils/lerp_utils.dart";

/// Size variants for [PregoQuickActionButton].
enum PregoQuickActionButtonSize {
  /// 110x110, icon + label, 20px padding.
  full,

  /// 84x60, icon only, 32px horizontal / 20px vertical padding.
  minimized,
}

const double _borderWidth = 0.5;

/// A quick action button matching the Figma `pregoQuickActionButton` component.
///
/// Supports two sizes ([PregoQuickActionButtonSize.full] and
/// [PregoQuickActionButtonSize.minimized]) with implicit transitions between them.
///
/// For scroll-driven transitions (e.g., collapsing headers), use
/// [PregoQuickActionButton.animated] which accepts a [collapseProgress] value
/// (0.0 = fully expanded, 1.0 = fully collapsed) to drive the transition
/// manually without implicit animation.
class PregoQuickActionButton extends StatelessWidget {
  /// Standard constructor with implicit size transitions.
  const PregoQuickActionButton({
    super.key,
    required this.size,
    required this.icon,
    required this.label,
    this.onTap,
    this.duration = kThemeAnimationDuration,
    this.curve = Curves.linearToEaseOut,
  }) : collapseProgress = null;

  /// Scroll-driven constructor for manual collapse animation.
  ///
  /// [collapseProgress] drives the transition:
  /// - `0.0` = fully expanded (full size with label)
  /// - `1.0` = fully collapsed (minimized, icon only)
  const PregoQuickActionButton.animated({
    super.key,
    required double this.collapseProgress,
    required this.icon,
    required this.label,
    this.onTap,
  }) : size = PregoQuickActionButtonSize.full,
       duration = Duration.zero,
       curve = Curves.easeInOut;

  final PregoQuickActionButtonSize size;
  final IconData icon;
  final String label;

  /// Called when the button is tapped. When `null`, the button renders
  /// in its disabled state.
  final VoidCallback? onTap;

  /// Collapse progress for the animated constructor (0.0 = full, 1.0 = minimized).
  final double? collapseProgress;

  /// Duration of the implicit collapse animation (standard constructor only).
  final Duration duration;

  /// Curve of the implicit collapse animation (standard constructor only).
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final collapseProgress = this.collapseProgress;
    if (collapseProgress != null) {
      return _PregoQuickActionButtonCore(
        curve: Curves.linear, // no curve for manual collapse
        collapseProgress: collapseProgress,
        icon: icon,
        label: label,
        onTap: onTap,
      );
    }

    final targetT = size == .minimized ? 1.0 : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: targetT),
      duration: duration,
      curve: curve,
      builder: (context, t, _) => _PregoQuickActionButtonCore(
        curve: curve,
        collapseProgress: t,
        icon: icon,
        label: label,
        onTap: onTap,
      ),
    );
  }
}

/// The core rendering widget. Always receives a concrete [collapseProgress].
class _PregoQuickActionButtonCore extends StatelessWidget {
  const _PregoQuickActionButtonCore({
    required this.collapseProgress,
    required this.icon,
    required this.label,
    required this.curve,
    required this.onTap,
  });

  final Curve curve;
  final double collapseProgress;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final t = collapseProgress.clamp(0.0, 1.0);
    final isEnabled = onTap != null;
    final borderSide = _buildDecorationBorderSide(prego: prego, isEnabled: isEnabled);

    return SizedBox(
      // size is NOT managed by the AnimatedContainer
      // because we only want implicit animation for
      // the decoration of the container, NOT the size.
      width: lerpDoubleNonNull(_fullWidth, _minimizedWidth, t),
      height: lerpDoubleNonNull(_fullHeight, _minimizedHeight, t),
      child: PregoTappable(
        onTap: onTap,
        overlayInset: _borderWidth, // prevent the overlay from painting over the border
        borderRadius: BorderRadius.circular(PregoRadius.x4l),
        useSuperellipse: true,
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered)) return prego.colors.bgGrayHover;
          if (states.contains(WidgetState.pressed)) return prego.colors.bgGrayPressed;
          return null;
        }),
        containerBuilder: (child) {
          final container = AnimatedContainer(
            duration: kThemeAnimationDuration,
            curve: curve,
            decoration: _buildDecoration(prego: prego, isEnabled: isEnabled, borderSide: borderSide),
            child: child,
          );

          return CustomPaint(
            foregroundPainter: isEnabled
                ? _GradientBorderPainter(
                    topColor: prego.colors.alphaBlack10,
                    bottomColor: prego.colors.alphaBlack20,
                    borderRadius: PregoRadius.x4l,
                    strokeWidth: _borderWidth,
                    position: .inside,
                  )
                : null,
            child: container,
          );
        },
        child: _PregoQuickActionButtonContentWidget(
          collapseProgress: t,
          isEnabled: isEnabled,
          icon: icon,
          label: label,
        ),
      ),
    );
  }

  BorderSide _buildDecorationBorderSide({required PregoDesignSystem prego, required bool isEnabled}) => isEnabled
      ? BorderSide
            .none // managed via CustomPaint
      : BorderSide(
          color: prego.colors.borderDisabled,
          width: _borderWidth,
        );

  ShapeDecoration _buildDecoration({
    required PregoDesignSystem prego,
    required bool isEnabled,
    required BorderSide borderSide,
  }) => ShapeDecoration(
    color: isEnabled ? prego.colors.bgPrimaryAlt : prego.colors.bgDisabled,
    shape: RoundedSuperellipseBorder(
      side: borderSide,
      borderRadius: BorderRadius.circular(PregoRadius.x4l),
    ),
    shadows: isEnabled ? prego.shadows.sm : null,
  );
}

class _PregoQuickActionButtonContentWidget extends StatelessWidget {
  const _PregoQuickActionButtonContentWidget({
    required this.collapseProgress,
    required this.isEnabled,
    required this.icon,
    required this.label,
  });

  final double collapseProgress;
  final bool isEnabled;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final iconAndTextColor = isEnabled ? prego.colors.textPrimary : prego.colors.textDisabled;
    final labelOpacity = (1.0 - collapseProgress * 2).clamp(0.0, 1.0);

    final horizontalPadding = lerpDoubleNonNull(PregoSpacing.x2l, PregoSpacing.x4l, collapseProgress);

    final child = Padding(
      padding: EdgeInsetsDirectional.only(
        start: horizontalPadding,
        end: horizontalPadding,
        top: PregoSpacing.x2l,
        bottom: PregoSpacing.x2l,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Icon(
              icon,
              size: 20,
              color: iconAndTextColor,
            ),
          ),
          if (labelOpacity > 0)
            Flexible(
              child: Text(
                label,
                style: prego.textTheme.textMd.bold.copyWith(
                  color: iconAndTextColor.withValues(alpha: iconAndTextColor.a * labelOpacity),
                ),
                maxLines: 1,
                // overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );

    return child;
  }
}

enum _BorderPosition { inside, center, outside }

/// Paints a gradient stroke following a [RoundedSuperellipseBorder] shape.
class _GradientBorderPainter extends CustomPainter {
  _GradientBorderPainter({
    required this.topColor,
    required this.bottomColor,
    required this.borderRadius,
    required this.strokeWidth,
    required this.position,
  });

  final Color topColor;
  final Color bottomColor;
  final double borderRadius;
  final double strokeWidth;
  final _BorderPosition position;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Signed offset from the shape edge to the centre of the stroke path:
    //   outside →  +strokeWidth/2  (stroke fully outside the shape)
    //   center  →   0              (stroke straddles the edge)
    //   inside  →  -strokeWidth/2  (stroke fully inside the shape)
    final inset = switch (position) {
      _BorderPosition.outside => strokeWidth / 2,
      _BorderPosition.center => 0.0,
      _BorderPosition.inside => -strokeWidth / 2,
    };

    // Both the rect and the border radius are offset by the same amount so
    // the inflated path is a true parallel of the original shape.
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular((borderRadius + inset).clamp(0.0, double.infinity)),
    );
    final strokeRect = rect.inflate(inset);
    final path = shape.getOuterPath(strokeRect);

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, bottomColor],
      ).createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter oldDelegate) =>
      topColor != oldDelegate.topColor ||
      bottomColor != oldDelegate.bottomColor ||
      borderRadius != oldDelegate.borderRadius ||
      strokeWidth != oldDelegate.strokeWidth ||
      position != oldDelegate.position;
}

// Full size: 110x110
const double _fullWidth = 110;
const double _fullHeight = 110;

// Minimized size: 84x60 (Figma pregoQuickActionButton minimized)
const double _minimizedWidth = 84;
const double _minimizedHeight = 60;
