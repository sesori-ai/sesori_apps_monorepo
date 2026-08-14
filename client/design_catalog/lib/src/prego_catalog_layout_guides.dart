import "package:flutter/widgets.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:theme_prego/module_prego.dart";
import "package:widgetbook/widgetbook.dart";

const _contentPadding = PregoSpacing.containerPaddingMobile;
const _minorGridInterval = PregoSpacing.xs;
const _majorGridInterval = PregoSpacing.md;
const _overlayKey = Key("prego-layout-guides-overlay");

/// URL-shareable layout-guide controls for the PREGO component canvas.
final class PregoLayoutGuidesAddon() extends WidgetbookAddon<PregoLayoutGuideSettings> {
  this : super(name: "Prego layout guides");

  @override
  List<Field<bool>> get fields => [
    _LabeledBooleanField(name: "enabled", label: "Enabled", initialValue: false),
    _LabeledBooleanField(name: "safeAreas", label: "Safe areas", initialValue: true),
    _LabeledBooleanField(name: "contentBounds", label: "Content bounds", initialValue: true),
    _LabeledBooleanField(name: "spacingGrid", label: "Spacing grid", initialValue: false),
  ];

  @override
  PregoLayoutGuideSettings valueFromQueryGroup(Map<String, String> group) => PregoLayoutGuideSettings(
    enabled: valueOf<bool>("enabled", group) ?? false,
    safeAreas: valueOf<bool>("safeAreas", group) ?? true,
    contentBounds: valueOf<bool>("contentBounds", group) ?? true,
    spacingGrid: valueOf<bool>("spacingGrid", group) ?? false,
  );

  @override
  Widget buildUseCase(
    BuildContext context,
    Widget child,
    PregoLayoutGuideSettings setting,
  ) {
    if (!setting.enabled) return child;

    final colors = context.prego.colors;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: _overlayKey,
              painter: PregoLayoutGuidesPainter(
                setting: setting,
                viewPadding: MediaQuery.viewPaddingOf(context),
                textDirection: Directionality.of(context),
                safeAreaFillColor: colors.fgWarningPrimary.withValues(alpha: 0.12),
                safeAreaEdgeColor: colors.fgWarningPrimary.withValues(alpha: 0.72),
                contentBoundsColor: colors.borderBrand.withValues(alpha: 0.92),
                majorGridColor: colors.fgBrandPrimary.withValues(alpha: 0.22),
                minorGridColor: colors.fgBrandPrimary.withValues(alpha: 0.10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _LabeledBooleanField({
  required super.name,
  required final String label,
  super.initialValue = true,
}) extends Field<bool> {
  this
    : super(
        defaultValue: true,
        type: FieldType.boolean,
        codec: FieldCodec(
          toParam: (value) => value.toString(),
          toValue: (param) => param == null ? null : param == "true",
        ),
      );

  @override
  Widget toWidget(BuildContext context, String group, bool? value) {
    return Row(
      children: [
        Expanded(child: material.Text(label)),
        material.Switch(
          value: value ?? initialValue ?? true,
          onChanged: (value) => updateField(context, group, value),
        ),
      ],
    );
  }
}

@immutable
final class const PregoLayoutGuideSettings({
  required final bool enabled,
  required final bool safeAreas,
  required final bool contentBounds,
  required final bool spacingGrid,
}) {
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PregoLayoutGuideSettings &&
          enabled == other.enabled &&
          safeAreas == other.safeAreas &&
          contentBounds == other.contentBounds &&
          spacingGrid == other.spacingGrid;

  @override
  int get hashCode => Object.hash(enabled, safeAreas, contentBounds, spacingGrid);
}

@visibleForTesting
final class const PregoLayoutGuideGeometry({
  required final Rect safeRect,
  required final Rect contentRect,
  required final double leadingContentX,
  required final double trailingContentX,
});

@visibleForTesting
PregoLayoutGuideGeometry calculatePregoLayoutGuideGeometry({
  required Size size,
  required EdgeInsets viewPadding,
  required TextDirection textDirection,
}) {
  final safeRect = Rect.fromLTRB(
    viewPadding.left,
    viewPadding.top,
    size.width - viewPadding.right,
    size.height - viewPadding.bottom,
  );
  final contentRect = Rect.fromLTRB(
    safeRect.left + _contentPadding,
    safeRect.top,
    safeRect.right - _contentPadding,
    safeRect.bottom,
  );

  return PregoLayoutGuideGeometry(
    safeRect: safeRect,
    contentRect: contentRect,
    leadingContentX: textDirection == TextDirection.ltr ? contentRect.left : contentRect.right,
    trailingContentX: textDirection == TextDirection.ltr ? contentRect.right : contentRect.left,
  );
}

@visibleForTesting
final class PregoLayoutGuidesPainter({
  required final PregoLayoutGuideSettings setting,
  required final EdgeInsets viewPadding,
  required final TextDirection textDirection,
  required final Color safeAreaFillColor,
  required final Color safeAreaEdgeColor,
  required final Color contentBoundsColor,
  required final Color majorGridColor,
  required final Color minorGridColor,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final geometry = calculatePregoLayoutGuideGeometry(
      size: size,
      viewPadding: viewPadding,
      textDirection: textDirection,
    );

    if (setting.safeAreas) _paintSafeAreas(canvas: canvas, size: size, safeRect: geometry.safeRect);
    if (setting.spacingGrid) _paintSpacingGrid(canvas: canvas, rect: geometry.contentRect);
    if (setting.contentBounds) _paintContentBounds(canvas: canvas, geometry: geometry);
  }

  void _paintSafeAreas({
    required Canvas canvas,
    required Size size,
    required Rect safeRect,
  }) {
    if (viewPadding == EdgeInsets.zero) return;

    final unsafeRegions = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(safeRect);
    canvas
      ..drawPath(unsafeRegions, Paint()..color = safeAreaFillColor)
      ..drawRect(
        safeRect,
        Paint()
          ..color = safeAreaEdgeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  void _paintSpacingGrid({required Canvas canvas, required Rect rect}) {
    final majorEvery = (_majorGridInterval / _minorGridInterval).round();
    final minorPaint = Paint()
      ..color = minorGridColor
      ..strokeWidth = 0.5;
    final majorPaint = Paint()
      ..color = majorGridColor
      ..strokeWidth = 1;

    canvas.save();
    canvas.clipRect(rect);

    var verticalIndex = 0;
    for (var x = rect.left; x <= rect.right; x += _minorGridInterval) {
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        verticalIndex % majorEvery == 0 ? majorPaint : minorPaint,
      );
      verticalIndex++;
    }

    var horizontalIndex = 0;
    for (var y = rect.top; y <= rect.bottom; y += _minorGridInterval) {
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        horizontalIndex % majorEvery == 0 ? majorPaint : minorPaint,
      );
      horizontalIndex++;
    }

    canvas.restore();
  }

  void _paintContentBounds({
    required Canvas canvas,
    required PregoLayoutGuideGeometry geometry,
  }) {
    final paint = Paint()
      ..color = contentBoundsColor
      ..strokeWidth = 1.5;
    canvas
      ..drawLine(
        Offset(geometry.leadingContentX, geometry.safeRect.top),
        Offset(geometry.leadingContentX, geometry.safeRect.bottom),
        paint,
      )
      ..drawLine(
        Offset(geometry.trailingContentX, geometry.safeRect.top),
        Offset(geometry.trailingContentX, geometry.safeRect.bottom),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant PregoLayoutGuidesPainter oldDelegate) =>
      setting != oldDelegate.setting ||
      viewPadding != oldDelegate.viewPadding ||
      textDirection != oldDelegate.textDirection ||
      safeAreaFillColor != oldDelegate.safeAreaFillColor ||
      safeAreaEdgeColor != oldDelegate.safeAreaEdgeColor ||
      contentBoundsColor != oldDelegate.contentBoundsColor ||
      majorGridColor != oldDelegate.majorGridColor ||
      minorGridColor != oldDelegate.minorGridColor;
}
