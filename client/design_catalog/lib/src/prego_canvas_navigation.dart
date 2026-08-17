import "package:flutter/widgets.dart";
import "package:widgetbook/widgetbook.dart";

import "review_tools/prego_review_tools.dart";

const _defaultZoom = 1.0;
const _minimumZoom = 0.5;
const _maximumZoom = 3.0;
const _canvasTransformKey = Key("prego-canvas-navigation-transform");

/// Keeps zoom URL-shareable while pan position stays transient. Moving the
/// canvas is explicit so production component gestures remain faithful.
final class PregoCanvasNavigationAddon() extends WidgetbookAddon<PregoCanvasNavigationSettings> {
  this : super(name: "Canvas navigation");

  @override
  List<Field> get fields => [
    _LabeledDoubleSliderField(
      name: "zoom",
      label: "Zoom",
      initialValue: _defaultZoom,
      min: _minimumZoom,
      max: _maximumZoom,
      divisions: 25,
      precision: 2,
    ),
    _LabeledBooleanField(
      name: "moveCanvas",
      label: "Move canvas (Interact mode)",
      initialValue: false,
    ),
  ];

  @override
  PregoCanvasNavigationSettings valueFromQueryGroup(Map<String, String> group) {
    final decodedZoom = valueOf<double>("zoom", group) ?? _defaultZoom;
    return PregoCanvasNavigationSettings(
      zoom: _sanitizeZoom(zoom: decodedZoom),
      moveCanvas: valueOf<bool>("moveCanvas", group) ?? false,
    );
  }

  @override
  Widget buildUseCase(
    BuildContext context,
    Widget child,
    PregoCanvasNavigationSettings setting,
  ) {
    final reviewTools = PregoReviewToolsScope.of(context);
    return _PregoCanvasNavigationViewport(
      key: ValueKey(reviewTools.annotationScope.identity),
      zoom: setting.zoom,
      moveCanvas: setting.moveCanvas && reviewTools.mode == PregoReviewMode.interact,
      child: child,
    );
  }
}

@immutable
final class const PregoCanvasNavigationSettings({
  required final double zoom,
  required final bool moveCanvas,
}) {
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PregoCanvasNavigationSettings && zoom == other.zoom && moveCanvas == other.moveCanvas;

  @override
  int get hashCode => Object.hash(zoom, moveCanvas);
}

final class _LabeledDoubleSliderField({
  required super.name,
  required final String label,
  required super.initialValue,
  required super.min,
  required super.max,
  required super.divisions,
  required super.precision,
}) extends DoubleSliderField {
  @override
  Widget toWidget(BuildContext context, String group, double? value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Text(label), super.toWidget(context, group, value)],
  );
}

final class _LabeledBooleanField({
  required super.name,
  required final String label,
  required super.initialValue,
}) extends BooleanField {
  @override
  Widget toWidget(BuildContext context, String group, bool? value) => Row(
    children: [
      Expanded(child: Text(label)),
      super.toWidget(context, group, value),
    ],
  );
}

class const _PregoCanvasNavigationViewport({
  required final double zoom,
  required final bool moveCanvas,
  required final Widget child,
  super.key,
}) extends StatefulWidget {
  @override
  State<_PregoCanvasNavigationViewport> createState() => _PregoCanvasNavigationViewportState();
}

final class _PregoCanvasNavigationViewportState() extends State<_PregoCanvasNavigationViewport> {
  late final TransformationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController(_matrixForZoom(zoom: widget.zoom));
  }

  @override
  void didUpdateWidget(covariant _PregoCanvasNavigationViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoom == widget.zoom) return;

    final translation = _controller.value.getTranslation();
    _controller.value = _matrixForZoom(zoom: widget.zoom)..setTranslationRaw(translation.x, translation.y, 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.moveCanvas) {
      return ClipRect(
        child: Transform(
          key: _canvasTransformKey,
          transform: _controller.value,
          alignment: Alignment.center,
          child: widget.child,
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: InteractiveViewer(
        key: _canvasTransformKey,
        transformationController: _controller,
        alignment: Alignment.center,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: _minimumZoom,
        maxScale: _maximumZoom,
        panEnabled: true,
        scaleEnabled: false,
        child: IgnorePointer(child: widget.child),
      ),
    );
  }
}

Matrix4 _matrixForZoom({required double zoom}) => Matrix4.diagonal3Values(zoom, zoom, 1);

double _sanitizeZoom({required double zoom}) {
  if (!zoom.isFinite) return _defaultZoom;
  return zoom.clamp(_minimumZoom, _maximumZoom).toDouble();
}
