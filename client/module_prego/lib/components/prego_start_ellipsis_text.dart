import "dart:math" as math;

import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";

/// One line of text that, when it does not fit, drops characters from its
/// start behind an ellipsis: "…Opus 5" rather than "Claude Op…". For names
/// whose distinguishing part comes last, the tail is what identifies them.
///
/// Flutter ellipsizes the end only, so this measures the text itself. Its
/// intrinsic width is that of the whole text, so an [IntrinsicWidth] parent
/// sizes to the full label when there is room. Screen readers always get the
/// whole [text].
///
/// It is a [Text] so that `find.text` and other code reading a label see the
/// whole string; only the rendering differs.
class const PregoStartEllipsisText({
  super.key,
  required final String text,
  required TextStyle style,
}) extends Text {
  this : super(text, style: style);

  @override
  Widget build(BuildContext context) {
    // The same resolution [Text] applies to its own style, bold text included.
    var resolved = DefaultTextStyle.of(context).style.merge(style);
    if (MediaQuery.boldTextOf(context)) {
      resolved = resolved.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    return _StartEllipsisRenderWidget(
      text: text,
      style: resolved,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
  }
}

class const _StartEllipsisRenderWidget({
  required final String text,
  required final TextStyle style,
  required final TextDirection textDirection,
  required final TextScaler textScaler,
}) extends LeafRenderObjectWidget {
  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderStartEllipsisText(text: text, style: style, textDirection: textDirection, textScaler: textScaler);

  @override
  void updateRenderObject(BuildContext context, RenderStartEllipsisText renderObject) {
    renderObject
      ..text = text
      ..style = style
      ..textDirection = textDirection
      ..textScaler = textScaler;
  }
}

/// The render box behind [PregoStartEllipsisText].
class RenderStartEllipsisText({
  required String text,
  required TextStyle style,
  required TextDirection textDirection,
  required TextScaler textScaler,
}) extends RenderBox {
  static const String _ellipsis = "…";

  final TextPainter _painter = TextPainter(maxLines: 1);

  String _text = text;
  String get text => _text;
  set text(String value) {
    if (value == _text) return;
    _text = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  TextStyle _style = style;
  TextStyle get style => _style;
  set style(TextStyle value) {
    if (value == _style) return;
    _style = value;
    markNeedsLayout();
  }

  TextDirection _textDirection = textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  TextScaler _textScaler = textScaler;
  TextScaler get textScaler => _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    markNeedsLayout();
  }

  /// Lays [candidate] out in the painter and returns its width.
  double _measure(String candidate) {
    _painter
      ..text = TextSpan(text: candidate, style: _style)
      ..textDirection = _textDirection
      ..textScaler = _textScaler
      ..layout();
    return _painter.width;
  }

  /// The longest tail of the text that fits [maxWidth] behind the ellipsis,
  /// or the whole text when it fits as it is.
  String _fit(double maxWidth) {
    if (_measure(_text) <= maxWidth) return _text;
    final characters = _text.characters;
    String tail(int count) => _ellipsis + characters.takeLast(count).toString().trimLeft();
    var low = 0;
    var high = characters.length;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_measure(tail(mid)) <= maxWidth) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return tail(low);
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.min(_measure(_ellipsis), _measure(_text));

  @override
  double computeMaxIntrinsicWidth(double height) => _measure(_text);

  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    _measure(_text);
    return _painter.height;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = _measure(_fit(constraints.maxWidth));
    return constraints.constrain(Size(width, _painter.height));
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    _measure(_fit(constraints.maxWidth));
    return _painter.computeDistanceToActualBaseline(baseline);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _measure(_fit(constraints.maxWidth));
    // Narrower than one ellipsis, the glyph would spill over a neighbour.
    context.canvas
      ..save()
      ..clipRect(offset & size);
    _painter.paint(context.canvas, offset);
    context.canvas.restore();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..label = _text
      ..textDirection = _textDirection;
  }

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }
}
