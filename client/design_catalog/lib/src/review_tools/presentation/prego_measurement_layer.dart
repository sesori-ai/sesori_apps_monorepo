// Catalog-only developer tooling is intentionally English and does not ship in product surfaces.
// ignore_for_file: no_slop_linter/avoid_string_literals_in_widgets

import "package:flutter/gestures.dart";
import "package:flutter/services.dart";
import "package:flutter/widgets.dart";
import "package:theme_prego/module_prego.dart";

import "prego_review_action.dart";
import "prego_review_target.dart";

const _snapThreshold = 6.0;

@immutable
final class const PregoMeasurement({required final Offset start, required final Offset end}) {
  double get horizontal => (end.dx - start.dx).abs();
  double get vertical => (end.dy - start.dy).abs();
  double get distance => (end - start).distance;
}

@visibleForTesting
Offset lockPregoMeasurementAxis({required Offset start, required Offset point}) {
  final delta = point - start;
  return delta.dx.abs() >= delta.dy.abs() ? Offset(point.dx, start.dy) : Offset(start.dx, point.dy);
}

@visibleForTesting
Offset snapPregoMeasurementPoint({
  required Offset point,
  required Size canvasSize,
  required List<Rect> targetRects,
  double threshold = _snapThreshold,
}) {
  final xCandidates = <double>[0, canvasSize.width];
  final yCandidates = <double>[0, canvasSize.height];
  for (final rect in targetRects) {
    xCandidates.addAll([rect.left, rect.center.dx, rect.right]);
    yCandidates.addAll([rect.top, rect.center.dy, rect.bottom]);
  }
  return Offset(
    _nearestAxis(value: point.dx, candidates: xCandidates, threshold: threshold),
    _nearestAxis(value: point.dy, candidates: yCandidates, threshold: threshold),
  );
}

double _nearestAxis({required double value, required List<double> candidates, required double threshold}) {
  var nearest = value;
  var distance = threshold;
  for (final candidate in candidates) {
    final candidateDistance = (candidate - value).abs();
    if (candidateDistance <= distance) {
      nearest = candidate;
      distance = candidateDistance;
    }
  }
  return nearest;
}

class const PregoMeasurementLayer({required final Widget child, super.key}) extends StatefulWidget {
  @override
  State<PregoMeasurementLayer> createState() => _PregoMeasurementLayerState();
}

class _PregoMeasurementLayerState() extends State<PregoMeasurementLayer> {
  static const _targetResolver = PregoReviewTargetResolver();

  final _rootKey = GlobalKey();
  final _contentKey = GlobalKey();
  final _hudKey = GlobalKey();
  final _focusNode = FocusNode(debugLabel: "Prego measurement tool");
  List<PregoMeasurement> _measurements = const [];
  PregoMeasurement? _current;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          _clear();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.precise,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: (_) => setState(() => _current = null),
          child: Stack(
            key: _rootKey,
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: AbsorbPointer(
                  child: KeyedSubtree(key: _contentKey, child: widget.child),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const Key("prego-measurement-overlay"),
                    painter: PregoMeasurementPainter(
                      measurements: _measurements,
                      current: _current,
                      lineColor: colors.borderBrand,
                      guideColor: colors.fgBrandPrimary.withValues(alpha: 0.45),
                      labelColor: colors.textPrimary,
                      labelBackground: colors.bgSurface1,
                      labelBorder: colors.borderSecondary,
                      textStyle: context.prego.textTheme.textXs.bold,
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: 12,
                start: 12,
                child: KeyedSubtree(
                  key: _hudKey,
                  child: _MeasurementHud(
                    count: _measurements.length,
                    onClear: _measurements.isEmpty && _current == null ? null : _clear,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons & kPrimaryMouseButton == 0 || _isInsideHud(event.position)) return;
    _focusNode.requestFocus();
    final start = _snap(globalPosition: event.position);
    if (start == null) return;
    setState(() => _current = PregoMeasurement(start: start, end: start));
  }

  void _onPointerMove(PointerMoveEvent event) {
    final current = _current;
    if (current == null) return;
    final snappedEnd = _snap(globalPosition: event.position);
    if (snappedEnd == null) return;
    final end = HardwareKeyboard.instance.isShiftPressed
        ? lockPregoMeasurementAxis(start: current.start, point: snappedEnd)
        : snappedEnd;
    setState(() => _current = PregoMeasurement(start: current.start, end: end));
  }

  void _onPointerUp(PointerUpEvent event) {
    final current = _current;
    if (current == null) return;
    var end = _snap(globalPosition: event.position) ?? current.end;
    if (HardwareKeyboard.instance.isShiftPressed) {
      end = lockPregoMeasurementAxis(start: current.start, point: end);
    }
    final completed = PregoMeasurement(start: current.start, end: end);
    setState(() {
      _measurements = completed.distance >= 1 ? [..._measurements, completed] : _measurements;
      _current = null;
    });
  }

  Offset? _snap({required Offset globalPosition}) {
    final root = _rootKey.currentContext?.findRenderObject();
    final content = _contentKey.currentContext?.findRenderObject();
    if (root is! RenderBox || content == null) return null;
    final local = root.globalToLocal(globalPosition);
    final clamped = Offset(
      local.dx.clamp(0, root.size.width).toDouble(),
      local.dy.clamp(0, root.size.height).toDouble(),
    );
    final rects = _targetResolver
        .collect(contentRoot: content)
        .map((target) => target.rectIn(root: root))
        .where((rect) => rect.overlaps(Offset.zero & root.size))
        .toList();
    return snapPregoMeasurementPoint(point: clamped, canvasSize: root.size, targetRects: rects);
  }

  bool _isInsideHud(Offset globalPosition) {
    final hud = _hudKey.currentContext?.findRenderObject();
    if (hud is! RenderBox || !hud.hasSize) return false;
    return (Offset.zero & hud.size).contains(hud.globalToLocal(globalPosition));
  }

  void _clear() {
    if (_measurements.isEmpty && _current == null) return;
    setState(() {
      _measurements = const [];
      _current = null;
    });
  }
}

class const _MeasurementHud({required final int count, required final VoidCallback? onClear}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    final textStyle = context.prego.textTheme.textXs.medium.copyWith(color: colors.textPrimary);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgSurface1,
        border: Border.all(color: colors.borderSecondary),
        borderRadius: BorderRadius.circular(PregoRadius.lg),
        boxShadow: context.prego.shadows.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Drag to measure · Shift locks · Esc clears", style: textStyle),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Text("$count pinned", style: textStyle.copyWith(color: colors.textSecondary)),
            ],
            if (onClear != null) ...[
              const SizedBox(width: 8),
              PregoReviewAction(
                label: "Clear measurements",
                text: "Clear",
                onPressed: onClear,
                foregroundColor: colors.textBrandSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
final class PregoMeasurementPainter({
  required final List<PregoMeasurement> measurements,
  required final PregoMeasurement? current,
  required final Color lineColor,
  required final Color guideColor,
  required final Color labelColor,
  required final Color labelBackground,
  required final Color labelBorder,
  required final TextStyle textStyle,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (final measurement in [...measurements, ?current]) {
      _paintMeasurement(canvas: canvas, measurement: measurement);
    }
  }

  void _paintMeasurement({required Canvas canvas, required PregoMeasurement measurement}) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2;
    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    final corner = Offset(measurement.end.dx, measurement.start.dy);
    canvas
      ..drawLine(measurement.start, corner, guidePaint)
      ..drawLine(corner, measurement.end, guidePaint)
      ..drawLine(measurement.start, measurement.end, linePaint)
      ..drawCircle(measurement.start, 3, linePaint)
      ..drawCircle(measurement.end, 3, linePaint);

    final label = _measurementLabel(measurement);
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: textStyle.copyWith(color: labelColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 4);
    final midpoint = Offset(
      (measurement.start.dx + measurement.end.dx) / 2,
      (measurement.start.dy + measurement.end.dy) / 2,
    );
    final rect = Rect.fromCenter(
      center: midpoint,
      width: textPainter.width + padding.horizontal,
      height: textPainter.height + padding.vertical,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = labelBackground,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = labelBorder
        ..style = PaintingStyle.stroke,
    );
    textPainter.paint(canvas, rect.topLeft + Offset(padding.left, padding.top));
  }

  @override
  bool shouldRepaint(covariant PregoMeasurementPainter oldDelegate) =>
      measurements != oldDelegate.measurements ||
      current != oldDelegate.current ||
      lineColor != oldDelegate.lineColor ||
      guideColor != oldDelegate.guideColor ||
      labelColor != oldDelegate.labelColor ||
      labelBackground != oldDelegate.labelBackground ||
      labelBorder != oldDelegate.labelBorder ||
      textStyle != oldDelegate.textStyle;
}

String _measurementLabel(PregoMeasurement measurement) {
  if (measurement.horizontal < 0.1) return "${_format(measurement.vertical)} px";
  if (measurement.vertical < 0.1) return "${_format(measurement.horizontal)} px";
  return "${_format(measurement.horizontal)} × ${_format(measurement.vertical)} · ${_format(measurement.distance)} px";
}

String _format(double value) {
  final rounded = value.roundToDouble();
  return (value - rounded).abs() < 0.05 ? rounded.toInt().toString() : value.toStringAsFixed(1);
}
