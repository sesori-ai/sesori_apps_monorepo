import "package:flutter/rendering.dart";
import "package:flutter/scheduler.dart";
import "package:material_ui/material_ui.dart";

/// A halo of the page's own background, so a floating surface lifts off the
/// content passing under it without the glyphs its edge cuts through crowding
/// it. The pinned prompt and the floating bottom controls share it. Judge it
/// with shadows enabled: `flutter_test` disables the blur.
BoxShadow pageHaloShadow({required Color color}) => BoxShadow(color: color, blurRadius: 28, spreadRadius: 14);

/// Paints the [PageHalo] of every control below it in one layer beneath all of
/// them, so the halos of neighbouring controls merge into one cloud of the
/// page's background instead of one halo covering the control beside it.
class const PageHaloLayer({super.key, required super.child}) extends SingleChildRenderObjectWidget {
  @override
  RenderPageHaloLayer createRenderObject(BuildContext context) =>
      RenderPageHaloLayer(color: Theme.of(context).scaffoldBackgroundColor);

  @override
  void updateRenderObject(BuildContext context, RenderPageHaloLayer renderObject) {
    renderObject.color = Theme.of(context).scaffoldBackgroundColor;
  }
}

/// Gives a floating control a [pageHaloShadow], painted by the nearest
/// [PageHaloLayer] above it. Without a layer the control has no halo.
class const PageHalo({
  super.key,

  /// The control's corner radius, which the halo follows.
  required final double radius,

  /// Whether the halo runs on to the layer's bottom edge, so that no content
  /// shows below the bottom-most control.
  required final bool reachesLayerBottom,
  required super.child,
}) extends SingleChildRenderObjectWidget {
  @override
  RenderPageHalo createRenderObject(BuildContext context) =>
      RenderPageHalo(radius: radius, reachesLayerBottom: reachesLayerBottom);

  @override
  void updateRenderObject(BuildContext context, RenderPageHalo renderObject) {
    renderObject
      ..radius = radius
      ..reachesLayerBottom = reachesLayerBottom;
  }
}

class RenderPageHaloLayer({required Color color}) extends RenderProxyBox {
  Color _color = color;
  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  final Set<RenderPageHalo> _halos = {};
  bool _repaintScheduled = false;

  void _add(RenderPageHalo halo) {
    _halos.add(halo);
    markNeedsPaint();
  }

  void _remove(RenderPageHalo halo) {
    _halos.remove(halo);
    if (attached) markNeedsPaint();
  }

  /// Repaints once the frame being painted ends, for a halo that moved or
  /// faded without this layer painting.
  void _scheduleRepaint() {
    if (_repaintScheduled) return;
    _repaintScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _repaintScheduled = false;
      if (attached) markNeedsPaint();
    }, debugLabel: "PageHaloLayer.repaint");
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var fading = false;
    for (final halo in _halos) {
      if (!halo.hasSize) continue;
      final rect = halo._rectIn(layer: this);
      halo._paintedRect = rect;
      final (:opacity, :animating) = halo._opacityIn(layer: this);
      fading |= animating;
      if (opacity == 0) continue;
      final color = _color.withValues(alpha: _color.a * opacity);
      final radius = Radius.circular(halo._radius);
      final shape = halo._reachesLayerBottom
          ? RRect.fromRectAndCorners(
              Rect.fromLTRB(rect.left, rect.top, rect.right, size.height),
              topLeft: radius,
              topRight: radius,
            )
          : RRect.fromRectAndRadius(rect, radius);
      final shadow = pageHaloShadow(color: color);
      // The solid core keeps a translucent control, or the gap below the
      // bottom-most one, as opaque as the page.
      context.canvas
        ..drawRRect(shape.shift(offset).inflate(shadow.spreadRadius), shadow.toPaint())
        ..drawRRect(shape.shift(offset), Paint()..color = color);
    }
    // A fading control takes its halo with it, frame by frame.
    if (fading) _scheduleRepaint();
    super.paint(context, offset);
  }
}

class RenderPageHalo({required double radius, required bool reachesLayerBottom}) extends RenderProxyBox {
  double _radius = radius;
  double get radius => _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    _layer?.markNeedsPaint();
  }

  bool _reachesLayerBottom = reachesLayerBottom;
  bool get reachesLayerBottom => _reachesLayerBottom;
  set reachesLayerBottom(bool value) {
    if (value == _reachesLayerBottom) return;
    _reachesLayerBottom = value;
    _layer?.markNeedsPaint();
  }

  RenderPageHaloLayer? _layer;

  /// Where [_layer] last painted this halo, in the layer's coordinates.
  Rect? _paintedRect;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (var node = parent; node != null; node = node.parent) {
      if (node is RenderPageHaloLayer) {
        _layer = node.._add(this);
        return;
      }
    }
  }

  @override
  void detach() {
    _layer?._remove(this);
    _layer = null;
    super.detach();
  }

  Rect _rectIn({required RenderPageHaloLayer layer}) =>
      MatrixUtils.transformRect(getTransformTo(layer), Offset.zero & size);

  /// This control's opacity within [layer], and whether a fade is changing it.
  ({double opacity, bool animating}) _opacityIn({required RenderPageHaloLayer layer}) {
    var opacity = 1.0;
    var animating = false;
    for (var node = parent; node != null && node != layer; node = node.parent) {
      switch (node) {
        case RenderOpacity():
          opacity *= node.opacity;
        case RenderAnimatedOpacity():
          opacity *= node.opacity.value;
          animating |= node.opacity.isAnimating;
      }
    }
    return (opacity: opacity, animating: animating);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Moved or resized behind a repaint boundary, such as a sibling pill
    // growing, without the layer repainting: catch the halo up.
    final layer = _layer;
    if (layer != null && _rectIn(layer: layer) != _paintedRect) layer._scheduleRepaint();
    super.paint(context, offset);
  }
}
