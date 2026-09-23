import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";

import "../../icons/tabler_icons.g.dart";
import "../../interactions/prego_interaction_scope.dart";
import "../../theme/prego_theme.dart";
import "../loaders/prego_activity_indicator.dart";
import "prego_popover.dart";

/// A row of a [PregoPickerSearchList].
sealed class const PregoPickerSearchRow();

/// A heading over the options that follow it. The highlight passes over it.
class const PregoPickerSearchHeading({required final String text}) extends PregoPickerSearchRow;

/// An option, picked by a tap or, under a pointer, by Enter while highlighted.
class const PregoPickerSearchOption({
  required final bool isSelected,
  required final VoidCallback onPick,
  required final Widget child,
}) extends PregoPickerSearchRow;

/// Opens a composer picker in a popover beside its trigger: [pointerWidth]
/// wide under a pointer, and as wide as the screen allows under touch.
class const PregoPickerPopover({
  super.key,
  required final double pointerWidth,
  required final PregoPopoverTriggerBuilder triggerBuilder,
  required final PregoPopoverContentBuilder contentBuilder,
  required final VoidCallback? onClosed,
}) extends StatelessWidget {
  /// How tall a composer picker or menu may grow before its rows scroll. It
  /// sizes itself to its rows below this; the cap only stops a long catalog
  /// (or a project with many agents) from swallowing the conversation behind
  /// it.
  static const double maxHeight = 380;

  @override
  Widget build(BuildContext context) {
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    return PregoPopover(
      popoverWidth: pointer ? pointerWidth : double.infinity,
      popoverMaxHeight: maxHeight,
      contentScrolls: true,
      // The composer's menus are tight under a pointer and roomy under touch.
      popoverBorderRadius: pointer ? PregoRadius.md : PregoRadius.x4l,
      triggerBuilder: triggerBuilder,
      contentBuilder: contentBuilder,
      onClosed: onClosed,
    );
  }
}

/// The body of a composer picker: a search field pinned above a list that
/// scrolls itself.
///
/// Under a pointer the field takes focus, so typing filters at once. Up and
/// Down move a highlight through the options, and so does the mouse; Enter
/// picks the highlighted option, and Esc closes the picker.
class const PregoPickerSearchList({
  super.key,
  required final String searchHint,

  /// Receives the trimmed, lowercased query.
  required final ValueChanged<String> onQueryChanged,

  /// The rows that match the query, or null while they load.
  required final List<PregoPickerSearchRow>? rows,

  /// Shown instead of an empty list; null shows nothing.
  required final String? emptyText,
  required final VoidCallback onClose,
}) extends StatefulWidget {
  @override
  State<PregoPickerSearchList> createState() => _PickerSearchListState();
}

class _PickerSearchListState() extends State<PregoPickerSearchList> {
  final _scrollController = ScrollController();
  final _highlightedKey = GlobalKey();

  /// The highlighted option's row index; null when no option matches.
  late int? _highlighted = _nextOption(after: -1, step: 1);

  @override
  void didUpdateWidget(PregoPickerSearchList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New matches start from the top.
    if (!identical(oldWidget.rows, widget.rows)) _highlighted = _nextOption(after: -1, step: 1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int? _nextOption({required int after, required int step}) {
    final rows = widget.rows ?? const <PregoPickerSearchRow>[];
    for (var index = after + step; index >= 0 && index < rows.length; index += step) {
      if (rows[index] is PregoPickerSearchOption) return index;
    }
    return null;
  }

  void _move({required int step}) {
    final highlighted = _highlighted;
    if (highlighted == null) return;
    final next = _nextOption(after: highlighted, step: step);
    if (next == null) return;
    setState(() => _highlighted = next);
    // The next option neighbours the last one, so the list has built it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _highlightedKey.currentContext;
      if (row == null) return;
      Scrollable.ensureVisible(
        row,
        alignmentPolicy: step > 0
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  void _pickHighlighted() {
    final highlighted = _highlighted;
    if (highlighted == null) return;
    if (widget.rows?[highlighted] case final PregoPickerSearchOption option) option.onPick();
  }

  void _setQuery(String value) {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    widget.onQueryChanged(value.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    final list = switch ((widget.rows, widget.emptyText)) {
      (null, _) => const Padding(
        padding: EdgeInsets.all(PregoSpacing.x3l),
        child: Center(child: PregoActivityIndicator(color: null)),
      ),
      ([], null) => const SizedBox.shrink(),
      ([], final String text) => Padding(
        padding: const EdgeInsets.all(PregoSpacing.x3l),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
        ),
      ),
      (final List<PregoPickerSearchRow> rows, _) => ListView.builder(
        controller: _scrollController,
        // Still lazy: the popover's height cap bounds the list.
        shrinkWrap: true,
        padding: pointer ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(vertical: 6),
        itemCount: rows.length,
        itemBuilder: (context, index) => switch (rows[index]) {
          PregoPickerSearchHeading(:final text) => _Heading(text: text, pointer: pointer),
          final PregoPickerSearchOption option => _OptionRow(
            key: index == _highlighted ? _highlightedKey : null,
            option: option,
            pointer: pointer,
            isHighlighted: pointer && index == _highlighted,
            onHover: () {
              if (_highlighted != index) setState(() => _highlighted = index);
            },
          ),
        },
      ),
    };

    return CallbackShortcuts(
      bindings: pointer
          ? {
              const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(step: 1),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(step: -1),
              const SingleActivator(LogicalKeyboardKey.enter): _pickHighlighted,
              const SingleActivator(LogicalKeyboardKey.numpadEnter): _pickHighlighted,
              // Wins over the desktop's own Esc, which would only leave the field.
              const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
            }
          : const {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: pointer
                ? const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 0)
                : const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 0),
            child: TextField(
              autofocus: pointer,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(TablerRegular.search, size: PregoIconSize.md),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(pointer ? PregoRadius.sm : PregoRadius.x4l),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: prego.colors.bgSurface1,
              ),
              onChanged: _setQuery,
            ),
          ),
          Flexible(child: list),
        ],
      ),
    );
  }
}

/// A provider or group heading, styled as the composer menus' labels.
class const _Heading({required final String text, required final bool pointer}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: pointer
          ? const EdgeInsetsDirectional.fromSTEB(10, 6, 10, 2)
          : const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textSecondary, letterSpacing: 0.8),
        ),
      ),
    );
  }
}

/// An option row, sized as the composer menus' rows: a 30 px row under a
/// pointer, which rounds its own highlight, and a 54 px touch target.
class const _OptionRow({
  super.key,
  required final PregoPickerSearchOption option,
  required final bool pointer,
  required final bool isHighlighted,
  required final VoidCallback onHover,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final radius = BorderRadius.circular(pointer ? PregoRadius.sm : 0);
    return Semantics(
      selected: option.isSelected,
      // Only a moving mouse takes the highlight, so rows that scroll under a
      // resting one leave the keyboard's highlight alone.
      child: MouseRegion(
        onHover: pointer ? (_) => onHover() : null,
        child: InkWell(
          onTap: option.onPick,
          hoverColor: pointer ? Colors.transparent : null,
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isHighlighted ? prego.colors.bgSecondaryHover : null,
              borderRadius: radius,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: pointer ? 30 : 54),
              child: Padding(
                padding: pointer
                    ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: option.child),
                    if (option.isSelected) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check, size: PregoIconSize.sm, color: prego.colors.bgBrandSolid),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
