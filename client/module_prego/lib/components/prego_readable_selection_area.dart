import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";

/// A selection area that preserves structural boundaries between text widgets
/// when copying across them.
class const PregoReadableSelectionArea({
  super.key,
  required final Widget child,
  final bool preserveEmptyLines = false,
}) extends StatefulWidget {
  /// Invisible selectable content used by callers that need a blank source
  /// line to survive the selection-container boundary.
  static const String emptyLineMarker = "\u200B";
  @override
  State<PregoReadableSelectionArea> createState() => _PregoReadableSelectionAreaState();
}

class _PregoReadableSelectionAreaState() extends State<PregoReadableSelectionArea> {
  late final _selectionDelegate = _ReadableSelectionContainerDelegate(
    preserveEmptyLines: widget.preserveEmptyLines,
  );

  @override
  void dispose() {
    _selectionDelegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: SelectionContainer(
        delegate: _selectionDelegate,
        child: widget.child,
      ),
    );
  }
}

class _ReadableSelectionContainerDelegate({required final bool preserveEmptyLines})
    extends StaticSelectionContainerDelegate {
  static const _sameLineTolerance = 3.0;
  final bool _preserveEmptyLines = preserveEmptyLines;

  @override
  SelectedContent? getSelectedContent() {
    final parts = <({Selectable selectable, String text})>[
      for (final selectable in selectables)
        if (selectable.getSelectedContent() case final SelectedContent content)
          if (_selectedText(selectable: selectable, content: content) case final text?
              when text.isNotEmpty ||
                  _preserveEmptyLines && content.plainText == PregoReadableSelectionArea.emptyLineMarker)
            (selectable: selectable, text: text),
    ];
    if (parts.isEmpty) return null;

    final buffer = StringBuffer();
    Rect? previousBounds;
    String? previousText;
    for (final part in parts) {
      final bounds = _screenBounds(selectable: part.selectable);
      if (previousBounds != null && bounds != null && previousText != null) {
        final separator = _separator(
          previousBounds: previousBounds,
          currentBounds: bounds.first,
          previousText: previousText,
          currentText: part.text,
        );
        buffer.write(separator);
      }
      buffer.write(part.text);
      previousBounds = bounds?.last ?? previousBounds;
      previousText = part.text;
    }
    return SelectedContent(plainText: buffer.toString());
  }

  String? _selectedText({required Selectable selectable, required SelectedContent content}) {
    if (content.plainText == PregoReadableSelectionArea.emptyLineMarker) {
      return "";
    }
    if (content.plainText.isNotEmpty) {
      return content.plainText;
    }
    if (_preserveEmptyLines && selectable.value.hasSelection) {
      return "";
    }
    return null;
  }

  ({Rect first, Rect last})? _screenBounds({required Selectable selectable}) {
    final transform = selectable.getTransformTo(null);
    if (selectable.boundingBoxes case final boxes when boxes.isNotEmpty) {
      return (
        first: MatrixUtils.transformRect(transform, boxes.first),
        last: MatrixUtils.transformRect(transform, boxes.last),
      );
    }

    // An empty RenderParagraph has no glyph boxes, but a selected collapsed
    // range still exposes its caret position. Use that position as a zero-width
    // line box so an intentionally selected blank source row remains a real
    // boundary in copied text.
    final geometry = selectable.value;
    final start = geometry.startSelectionPoint;
    final end = geometry.endSelectionPoint;
    if (start == null || end == null) return null;
    final firstPosition = start.localPosition;
    final lastPosition = end.localPosition;
    final top = firstPosition.dy < lastPosition.dy ? firstPosition.dy : lastPosition.dy;
    final bottom = (firstPosition.dy > lastPosition.dy ? firstPosition.dy : lastPosition.dy) + start.lineHeight;
    final left = firstPosition.dx < lastPosition.dx ? firstPosition.dx : lastPosition.dx;
    final right = firstPosition.dx > lastPosition.dx ? firstPosition.dx : lastPosition.dx;
    final rect = Rect.fromLTRB(left, top, right, bottom);
    return (
      first: MatrixUtils.transformRect(transform, rect),
      last: MatrixUtils.transformRect(transform, rect),
    );
  }

  String _separator({
    required Rect previousBounds,
    required Rect currentBounds,
    required String previousText,
    required String currentText,
  }) {
    final verticalGap = currentBounds.top - previousBounds.bottom;
    if (verticalGap >= -_sameLineTolerance) {
      if (previousText.endsWith("\n") || currentText.startsWith("\n")) return "";
      return "\n";
    }
    if (currentBounds.left > previousBounds.right - 1 &&
        !_endsWithInlineWhitespace(text: previousText) &&
        !_startsWithInlineWhitespace(text: currentText)) {
      return " ";
    }
    return "";
  }

  bool _endsWithInlineWhitespace({required String text}) => text.endsWith(" ") || text.endsWith("\t");

  bool _startsWithInlineWhitespace({required String text}) => text.startsWith(" ") || text.startsWith("\t");
}
