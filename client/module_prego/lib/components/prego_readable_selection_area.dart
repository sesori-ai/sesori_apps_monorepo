import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";

/// A selection area that preserves structural boundaries between text widgets
/// when copying across them.
///
/// The holder of a [GlobalKey] to its [PregoReadableSelectionAreaState] can
/// read what is selected and select all of it, as a context menu's Copy and
/// Select text do.
///
/// An area inside another one is a part of it rather than an island of its
/// own: a selection runs from it into the text around it, as a drag runs from
/// one transcript message into the next, and copying takes the text of the
/// nested areas in screen order. [PregoSelectionOnlyInNestedAreas] keeps the
/// rest of a subtree, such as a row's chrome, out of the outer area's selection.
/// An area under a [SelectionContainer.disabled] is an island again.
class const PregoReadableSelectionArea({
  super.key,
  required final Widget child,
  final bool preserveEmptyLines = false,
}) extends StatefulWidget {
  /// Invisible selectable content used by callers that need a blank source
  /// line to survive the selection-container boundary.
  static const String emptyLineMarker = "\u200B";
  static const String _escapedEmptyLineMarker = "$emptyLineMarker$emptyLineMarker";

  /// Encodes source text for a selection area that preserves empty lines.
  ///
  /// Empty text becomes [emptyLineMarker]. Literal marker characters are
  /// doubled so the delegate can distinguish them from that synthetic empty
  /// line. Every selectable source line rendered inside a preserving area
  /// should use this method.
  static String encodeText({required String text}) {
    if (text.isEmpty) return emptyLineMarker;
    return text.replaceAll(emptyLineMarker, _escapedEmptyLineMarker);
  }

  @override
  State<PregoReadableSelectionArea> createState() => PregoReadableSelectionAreaState();
}

class PregoReadableSelectionAreaState() extends State<PregoReadableSelectionArea> {
  late final _selectionDelegate = _ReadableSelectionContainerDelegate(
    preserveEmptyLines: widget.preserveEmptyLines,
  );
  final _selectionArea = GlobalKey<SelectionAreaState>();
  final _focusNode = _KeepingFocusNode(debugLabel: "PregoReadableSelectionArea");

  /// The area this one is nested in, which owns the selection; null when
  /// this one is outermost.
  PregoReadableSelectionAreaState? _outer;

  /// The selected text, as copying it gives it, or null when none of it is
  /// in this area. In a nested area, that is all of the outer area's
  /// selection, which may run beyond this one.
  String? get selectedText => switch (_outer) {
    final outer? => _selectionDelegate.getSelectedContent() == null ? null : outer.selectedText,
    null => _selectionDelegate.getSelectedContent()?.plainText,
  };

  /// Keeps the selection while [keep] is on, though the area loses the focus,
  /// as it does to a menu opened on its text. Losing the focus otherwise
  /// clears it. The region never sees the loss, so its selection stays whole
  /// and a shift-click afterwards extends it.
  void keepSelection({required bool keep}) {
    if (_outer case final outer?) return outer.keepSelection(keep: keep);
    _focusNode.keeps = keep;
  }

  /// Selects all of the area's text, and only it in a nested area, and shows
  /// the selection's handles and toolbar, taking the focus as a long-press
  /// selection does, so tapping elsewhere clears it.
  void selectAll() {
    if (_outer case final outer?) return outer._selectOnly(nested: _selectionDelegate);
    _focusNode.requestFocus();
    _selectionArea.currentState?.selectableRegion.selectAll(SelectionChangedCause.toolbar);
  }

  /// Selects all of [nested]'s text and nothing else. Selecting everything
  /// first shows the handles and toolbar, then a word selection at [nested]'s
  /// text narrows it to that area. A scrollable between them takes a
  /// select-all only as selecting all it holds, and records the edges of a
  /// word selection, which a handle dragged into another area needs.
  void _selectOnly({required _ReadableSelectionContainerDelegate nested}) {
    final anchor = nested.textAnchor;
    if (anchor == null) return;
    selectAll();
    _selectionDelegate.only = nested;
    try {
      _selectionDelegate.dispatchSelectionEvent(SelectWordSelectionEvent(globalPosition: anchor));
    } finally {
      _selectionDelegate.only = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Where the outer area's selection does not reach, under a
    // [SelectionContainer.disabled], this area selects on its own.
    final reached = SelectionContainer.maybeOf(context) != null || _NestedAreaRegistrarScope.maybeOf(context) != null;
    final outer = reached ? _OuterSelectionAreaScope.maybeOf(context) : null;
    if (outer == _outer) return;
    _outer?._selectionDelegate.nested.remove(_selectionDelegate);
    outer?._selectionDelegate.nested.add(_selectionDelegate);
    _selectionDelegate.outer = outer?._selectionDelegate;
    _outer = outer;
  }

  @override
  void didUpdateWidget(covariant PregoReadableSelectionArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preserveEmptyLines != widget.preserveEmptyLines) {
      _selectionDelegate.update(preserveEmptyLines: widget.preserveEmptyLines);
    }
  }

  @override
  void dispose() {
    _outer?._selectionDelegate.nested.remove(_selectionDelegate);
    _selectionDelegate.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_outer != null) {
      return SelectionContainer(
        // Under a [PregoSelectionOnlyInNestedAreas] there is no ambient
        // registrar, so the area joins the one that subtree hides.
        registrar: SelectionContainer.maybeOf(context) ?? _NestedAreaRegistrarScope.maybeOf(context),
        delegate: _selectionDelegate,
        child: widget.child,
      );
    }
    return _OuterSelectionAreaScope(
      area: this,
      child: SelectionArea(
        key: _selectionArea,
        focusNode: _focusNode,
        child: SelectionContainer(
          delegate: _selectionDelegate,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Keeps [child] out of the selection of the [PregoReadableSelectionArea]
/// around it, apart from the areas nested in [child], which stay part of that
/// selection. A transcript row uses it so a drag selects its messages' text
/// but not its timestamp or status lines.
class const PregoSelectionOnlyInNestedAreas({super.key, required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final registrar = SelectionContainer.maybeOf(context);
    if (registrar == null) return child;
    return _NestedAreaRegistrarScope(
      registrar: registrar,
      child: SelectionContainer.disabled(child: child),
    );
  }
}

/// The outermost [PregoReadableSelectionArea], which the areas nested in it
/// join.
class const _OuterSelectionAreaScope({
  required final PregoReadableSelectionAreaState area,
  required super.child,
}) extends InheritedWidget {
  static PregoReadableSelectionAreaState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_OuterSelectionAreaScope>()?.area;

  @override
  bool updateShouldNotify(_OuterSelectionAreaScope oldWidget) => area != oldWidget.area;
}

/// The registrar a [PregoSelectionOnlyInNestedAreas] hides from its subtree,
/// which the areas nested in it register with.
class const _NestedAreaRegistrarScope({
  required final SelectionRegistrar registrar,
  required super.child,
}) extends InheritedWidget {
  static SelectionRegistrar? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_NestedAreaRegistrarScope>()?.registrar;

  @override
  bool updateShouldNotify(_NestedAreaRegistrarScope oldWidget) => registrar != oldWidget.registrar;
}

/// Reports the focus while [keeps] is on, so the selection region does not
/// clear its selection when a menu takes the focus.
class _KeepingFocusNode({super.debugLabel}) extends FocusNode {
  bool keeps = false;

  @override
  bool get hasFocus => keeps || super.hasFocus;
}

class _ReadableSelectionContainerDelegate({required bool preserveEmptyLines}) extends StaticSelectionContainerDelegate {
  static const _sameLineTolerance = 3.0;
  bool _preserveEmptyLines = preserveEmptyLines;

  /// The delegates of the areas nested in this one's. While there are any,
  /// the text sits in them, and copying takes it from them in screen order:
  /// the scrollable between them would join it without line breaks.
  final nested = <_ReadableSelectionContainerDelegate>{};

  /// The outer area's delegate, while this one's area is nested in it.
  _ReadableSelectionContainerDelegate? outer;

  /// The nested delegate a word selection selects all of, while it runs.
  _ReadableSelectionContainerDelegate? only;

  /// A point on this area's first text, in global coordinates, or null when
  /// it has none laid out.
  Offset? get textAnchor {
    for (final selectable in selectables) {
      if (selectable.boundingBoxes case [final box, ...]) {
        return MatrixUtils.transformPoint(selectable.getTransformTo(null), box.center);
      }
    }
    return null;
  }

  void update({required bool preserveEmptyLines}) {
    if (_preserveEmptyLines == preserveEmptyLines) return;
    _preserveEmptyLines = preserveEmptyLines;
    notifyListeners();
  }

  @override
  SelectionResult handleSelectWord(SelectWordSelectionEvent event) {
    if (only != null) {
      // Cleared within the same event, the region never sees the selection
      // empty, which would drop its handles and toolbar.
      handleClearSelection(const ClearSelectionEvent());
    } else if (outer?.only == this) {
      handleSelectAll(const SelectAllSelectionEvent());
      return SelectionResult.end;
    }
    return super.handleSelectWord(event);
  }

  @override
  SelectedContent? getSelectedContent() {
    final List<({Selectable selectable, String text})> parts;
    if (nested.isEmpty) {
      parts = _selectedParts();
    } else {
      final areas = [
        for (final area in nested)
          if (area._selectedParts() case final areaParts when areaParts.isNotEmpty) areaParts,
      ]..sort((a, b) => compareOrder(a.first.selectable, b.first.selectable));
      parts = [for (final areaParts in areas) ...areaParts];
    }
    return _join(parts: parts);
  }

  /// This area's own selected text widgets, in order, with their text.
  List<({Selectable selectable, String text})> _selectedParts() => [
    for (final selectable in selectables)
      if (selectable.getSelectedContent() case final SelectedContent content)
        if (_selectedText(selectable: selectable, content: content) case final text?
            when text.isNotEmpty ||
                _preserveEmptyLines &&
                    (content.plainText == PregoReadableSelectionArea.emptyLineMarker || selectable.value.hasSelection))
          (selectable: selectable, text: text),
  ];

  SelectedContent? _join({required List<({Selectable selectable, String text})> parts}) {
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
      return content.plainText.replaceAll(
        PregoReadableSelectionArea._escapedEmptyLineMarker,
        PregoReadableSelectionArea.emptyLineMarker,
      );
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
