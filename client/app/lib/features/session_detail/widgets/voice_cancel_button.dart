import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";

/// The cancel target shown in the accordion's place while a hold-to-talk
/// recording runs.
///
/// At rest it is a dash-bordered ghost of an X button. As the recording hold
/// drags toward it ([progress] rising toward 1) the dashes give way to a solid
/// destructive fill, matching the design's `Recording` → `Deleting` states —
/// releasing at 1 discards the recording. A plain tap (a second finger, or
/// after the hold) cancels outright.
///
/// Driven by [progress] straight into the painter, so the drag scrubs colour
/// without rebuilding the composer.
class const VoiceCancelButton({
    super.key,
    required this.progress,
    required this.onCancel,
  }) extends StatelessWidget {
  /// 0 → resting dashed ghost, 1 → solid destructive fill under the finger.
  final ValueListenable<double> progress;

  final VoidCallback onCancel;

  /// Matches the 44pt footprint of the accordion pill it replaces.
  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return Semantics(
      button: true,
      label: loc.voiceCancelRecording,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onCancel,
        // The drag scrubs repaints at pointer-move rate; keep them off the
        // surrounding composer layer.
        child: RepaintBoundary(
          child: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, value, _) {
              final engaged = value.clamp(0.0, 1.0);
              // The explicit box carries the footprint: a CustomPaint with a
              // child sizes to that child, and the centred 20px icon would
              // shrink both the ring and the tap target.
              return SizedBox.square(
                dimension: _size,
                child: CustomPaint(
                  painter: _CancelTargetPainter(
                    engaged: engaged,
                    dashColor: prego.colors.borderDisabled,
                    fillColor: prego.colors.bgErrorSolid,
                    // The filled state's hairline ring, from the design's
                    // 2px rgba(255,255,255,0.12) border.
                    ringColor: prego.colors.textWhite.withValues(alpha: 0.12),
                  ),
                  child: Center(
                    child: Icon(
                      TablerRegular.x,
                      size: 20,
                      color:
                          Color.lerp(prego.colors.textSecondary, prego.colors.textWhite, engaged) ??
                          prego.colors.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Paints the dashed resting ring, cross-fading into the solid destructive
/// disc as [engaged] rises.
class _CancelTargetPainter({
    required this.engaged,
    required this.dashColor,
    required this.fillColor,
    required this.ringColor,
  }) extends CustomPainter {
  final double engaged;
  final Color dashColor;
  final Color fillColor;
  final Color ringColor;

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
  bool shouldRepaint(covariant _CancelTargetPainter oldDelegate) {
    return oldDelegate.engaged != engaged ||
        oldDelegate.dashColor != dashColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.ringColor != ringColor;
  }
}
