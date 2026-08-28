import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";

class const PregoSizeObserver({
  super.key,
  required final ValueChanged<Size> onSizeChanged,
  required super.child,
}) extends SingleChildRenderObjectWidget {
  @override
  PregoSizeObserverRenderObject createRenderObject(BuildContext context) =>
      PregoSizeObserverRenderObject(onSizeChanged: onSizeChanged);

  @override
  void updateRenderObject(BuildContext context, PregoSizeObserverRenderObject renderObject) {
    renderObject.onSizeChanged = onSizeChanged;
  }
}

class PregoSizeObserverRenderObject({required var ValueChanged<Size> onSizeChanged}) extends RenderProxyBox {
  Size? _lastReportedSize;

  @override
  void performLayout() {
    super.performLayout();
    final currentSize = size;
    if (currentSize == _lastReportedSize) return;
    _lastReportedSize = currentSize;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSizeChanged(currentSize));
  }
}
