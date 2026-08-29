import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";

/// A selection area that preserves the visual separation between text widgets
/// when copying across them.
class const ReadableSelectionArea({super.key, required final Widget child}) extends StatefulWidget {
  @override
  State<ReadableSelectionArea> createState() => _ReadableSelectionAreaState();
}

class _ReadableSelectionAreaState() extends State<ReadableSelectionArea> {
  final _selectionDelegate = _ReadableSelectionContainerDelegate();

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

class _ReadableSelectionContainerDelegate() extends StaticSelectionContainerDelegate {
  static const _sameLineTolerance = 3.0;
  static const _blankLineGap = 4.0;

  @override
  SelectedContent? getSelectedContent() {
    final parts = <({Selectable selectable, SelectedContent content})>[
      for (final selectable in selectables)
        if (selectable.getSelectedContent() case final SelectedContent content)
          if (content.plainText.isNotEmpty) (selectable: selectable, content: content),
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
          currentText: part.content.plainText,
        );
        buffer.write(separator);
      }
      buffer.write(part.content.plainText);
      previousBounds = bounds?.last ?? previousBounds;
      previousText = part.content.plainText;
    }
    return SelectedContent(plainText: buffer.toString());
  }

  ({Rect first, Rect last})? _screenBounds({required Selectable selectable}) {
    if (selectable.boundingBoxes.isEmpty) return null;
    final transform = selectable.getTransformTo(null);
    return (
      first: MatrixUtils.transformRect(transform, selectable.boundingBoxes.first),
      last: MatrixUtils.transformRect(transform, selectable.boundingBoxes.last),
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
      return verticalGap > _blankLineGap ? "\n\n" : "\n";
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
