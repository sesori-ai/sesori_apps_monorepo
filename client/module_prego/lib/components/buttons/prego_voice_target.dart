import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";

import "../../theme/prego_theme.dart";

/// The fill a [PregoVoiceTarget] rises into.
enum PregoVoiceTargetTone() {
  /// Solid destructive: releasing here throws the recording away.
  destructive,

  /// Solid primary: releasing here keeps the words.
  primary,
}

/// The target shown in the accordion's place while a recording runs.
///
/// At rest it is a dash-bordered ghost of an icon button. As the hold drags
/// toward it ([progress] rising toward 1) the dashes give way to a solid fill
/// in its [tone], matching the design's `Recording` → `Deleting` states —
/// releasing at 1 does what the icon says. A plain tap (a second finger, or
/// after the hold) does it outright.
///
/// Driven by [progress] straight into the painter, so the drag scrubs colour
/// without rebuilding the composer.
class const PregoVoiceTarget({
  super.key,
  required final IconData icon,
  required final PregoVoiceTargetTone tone,

  /// Announced by assistive technologies; the consumer localizes it.
  required final String semanticLabel,

  /// 0 → resting dashed ghost, 1 → solid fill under the finger.
  required final ValueListenable<double> progress,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  /// Matches the 44pt footprint of the accordion pill it replaces.
  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final (fillColor, ringColor, engagedIconColor) = switch (tone) {
      // The filled state's hairline ring, from the design's 2px
      // rgba(255,255,255,0.12) border.
      PregoVoiceTargetTone.destructive => (
        prego.colors.bgErrorSolid,
        prego.colors.textWhite.withValues(alpha: 0.12),
        prego.colors.textWhite,
      ),
      // The colours of the Send button, whose place it takes in the gesture.
      PregoVoiceTargetTone.primary => (
        prego.colors.fgPrimary,
        prego.colors.fgPrimary,
        prego.colors.textPrimaryOnWhite,
      ),
    };

    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          // The drag scrubs repaints at pointer-move rate; keep them off the
          // surrounding composer layer.
          child: RepaintBoundary(
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (context, value, _) {
                final engaged = value.clamp(0.0, 1.0);
                // The explicit box carries the footprint: a CustomPaint with a
                // child sizes to that child, and the centred 18px icon would
                // shrink both the ring and the tap target.
                return SizedBox.square(
                  dimension: _size,
                  child: CustomPaint(
                    painter: _VoiceTargetPainter(
                      engaged: engaged,
                      dashColor: prego.colors.borderDisabled,
                      fillColor: fillColor,
                      ringColor: ringColor,
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: PregoIconSize.md,
                        color:
                            Color.lerp(prego.colors.textSecondary, engagedIconColor, engaged) ??
                            prego.colors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the dashed resting ring, cross-fading into the solid
/// disc as [engaged] rises.
class _VoiceTargetPainter({
  required final double engaged,
  required final Color dashColor,
  required final Color fillColor,
  required final Color ringColor,
}) extends CustomPainter {
  static const double _dashStrokeWidth = 1;
  static const double _ringStrokeWidth = 2;
  static const int _dashCount = 16;

  /// Fraction of each dash period that is drawn (the rest is gap).
  static const double _dashFill = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    if (engaged > 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = fillColor.withValues(alpha: fillColor.a * engaged),
      );
      canvas.drawCircle(
        center,
        radius - _ringStrokeWidth / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _ringStrokeWidth
          ..color = ringColor.withValues(alpha: ringColor.a * engaged),
      );
    }

    final dashAlpha = 1 - engaged;
    if (dashAlpha > 0) {
      final dashPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _dashStrokeWidth
        ..strokeCap = StrokeCap.round
        ..color = dashColor.withValues(alpha: dashColor.a * dashAlpha);
      final dashRadius = radius - _dashStrokeWidth / 2;
      final rect = Rect.fromCircle(center: center, radius: dashRadius);
      const period = 2 * math.pi / _dashCount;
      for (var i = 0; i < _dashCount; i++) {
        canvas.drawArc(rect, i * period, period * _dashFill, false, dashPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceTargetPainter oldDelegate) {
    return oldDelegate.engaged != engaged ||
        oldDelegate.dashColor != dashColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.ringColor != ringColor;
  }
}
