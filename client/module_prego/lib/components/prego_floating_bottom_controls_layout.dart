import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";

/// Fills its pane with a content that [controls] float over the bottom of, and
/// builds that content from their height.
///
/// The controls are laid out first and the content builds in that same layout,
/// so that it moves in the frame their height changes, where a post-frame
/// measurement would trail them by one. It therefore builds during layout, as
/// under a [LayoutBuilder]. Painting and touches go by the usual order, with the
/// controls on top.
class const PregoFloatingBottomControlsLayout({
  super.key,
  required final Widget Function(BuildContext context, double controlsHeight) contentBuilder,
  required final Widget? controls,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _Layout(
    children: [
      _ContentBuilder(builder: contentBuilder),
      ?controls,
    ],
  );
}

class const _Layout({required super.children}) extends MultiChildRenderObjectWidget {
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLayout();
}

final class _LayoutParentData() extends ContainerBoxParentData<RenderBox>;

class _RenderLayout()
    extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _LayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _LayoutParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _LayoutParentData) child.parentData = _LayoutParentData();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    // The children are the content and then, when there are any, the controls.
    if (firstChild case final _RenderContent content) {
      var controlsHeight = 0.0;
      if (childAfter(content) case final controls?) {
        controls.layout(BoxConstraints.tightFor(width: size.width), parentUsesSize: true);
        controlsHeight = controls.size.height;
        if (controls.parentData case final _LayoutParentData parentData) {
          parentData.offset = Offset(0, size.height - controlsHeight);
        }
      }
      invokeLayoutCallback<BoxConstraints>((_) => content.controlsHeight = controlsHeight);
      content.layout(BoxConstraints.tight(size));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class const _ContentBuilder({
  @override required final Widget Function(BuildContext context, double controlsHeight) builder,
}) extends AbstractLayoutBuilder<double> {
  @override
  RenderAbstractLayoutBuilderMixin<double, RenderBox> createRenderObject(BuildContext context) => _RenderContent();
}

class _RenderContent()
    extends RenderProxyBox
    with RenderObjectWithLayoutCallbackMixin, RenderAbstractLayoutBuilderMixin<double, RenderBox> {
  double _controlsHeight = 0;

  double get controlsHeight => _controlsHeight;

  set controlsHeight(double value) {
    if (value == _controlsHeight) return;
    _controlsHeight = value;
    scheduleLayoutCallback();
  }

  @override
  double get layoutInfo => controlsHeight;

  @override
  void performLayout() {
    runLayoutCallback();
    super.performLayout();
  }
}
