import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";

import "../../icons/tabler_icons.g.dart";
import "../../interactions/prego_interaction_scope.dart";
import "../../theme/prego_theme.dart";
import "../buttons/prego_buttons_solid.dart";
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

/// A line of quiet text among the rows, such as why nothing below an option
/// matches. The highlight passes over it.
class const PregoPickerSearchNote({required final String text}) extends PregoPickerSearchRow;

/// A full-width secondary pill pinned below a [PregoPickerSearchList], such as
/// one that clears a filter. A check after its label marks it as the current
/// choice.
class const PregoPickerSearchFooter({
  required final String label,
  required final IconData icon,
  required final bool isSelected,
  required final VoidCallback onPick,
});

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
/// scrolls itself, between an optional [header] and [footer] the search does
/// not filter.
///
/// Under a pointer the field takes focus, so typing filters at once. Up and
/// Down move a highlight through the header, the options and the footer, and
/// the mouse moves it across the options; Enter picks the highlighted entry,
/// and Esc closes the picker. The highlight starts on the first matching
/// option, so Enter after typing picks a match, and falls back to the header,
/// never the footer, when nothing matches. Under touch the field waits for a
/// tap, so opening a picker never raises the keyboard over the options.
class const PregoPickerSearchList({
  super.key,
  required final String searchHint,

  /// Receives the trimmed, lowercased query.
  required final ValueChanged<String> onQueryChanged,

  /// An option pinned above the search field, such as an action the query
  /// does not filter, set off from the field by a hairline. Up from the first
  /// option reaches it. Null shows the field first.
  required final PregoPickerSearchOption? header,

  /// A pill pinned below the list, outside its scroll and set off by a
  /// hairline. Down from the last option reaches it. In a body of fixed
  /// height, such as a phone sheet, it sits at the bottom edge, which rides
  /// the keyboard up when that takes the body's room.
  required final PregoPickerSearchFooter? footer,

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

  /// The highlighted option's index in [_entries], or [_footerIndex] for the
  /// footer; null when there is none.
  late int? _highlighted = _firstHighlight();

  /// What Up and Down move through: the header, then the rows, then the
  /// footer at [_footerIndex].
  List<PregoPickerSearchRow> get _entries => [?widget.header, ...?widget.rows];

  /// Where the rows start in [_entries].
  int get _rowsStart => widget.header == null ? 0 : 1;

  /// The footer's place in the highlight order, just past [_entries].
  int get _footerIndex => _entries.length;

  /// The first matching option, else the header; never the footer, so Enter
  /// after typing cannot pick it.
  int? _firstHighlight() {
    final first = _nextOption(after: _rowsStart - 1, step: 1);
    if (first != null && first < _footerIndex) return first;
    return widget.header == null ? null : 0;
  }

  @override
  void didUpdateWidget(PregoPickerSearchList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New matches start from the top.
    if (!identical(oldWidget.rows, widget.rows)) _highlighted = _firstHighlight();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int? _nextOption({required int after, required int step}) {
    final entries = _entries;
    final end = widget.footer == null ? entries.length : entries.length + 1;
    for (var index = after + step; index >= 0 && index < end; index += step) {
      if (index == entries.length || entries[index] is PregoPickerSearchOption) return index;
    }
    return null;
  }

  void _move({required int step}) {
    // With nothing highlighted, Down still reaches the footer.
    final next = _nextOption(after: _highlighted ?? -1, step: step);
    if (next == null) return;
    setState(() => _highlighted = next);
    // The next option neighbours the last one, so the list has built it. The
    // footer carries no key: it is outside the scroll.
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
    final entries = _entries;
    if (highlighted == entries.length) {
      widget.footer?.onPick();
    } else if (entries[highlighted] case final PregoPickerSearchOption option) {
      option.onPick();
    }
  }

  void _setQuery(String value) {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    widget.onQueryChanged(value.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    final header = widget.header;
    final footer = widget.footer;
    final rowsStart = _rowsStart;
    Widget optionRow({required PregoPickerSearchOption option, required int entry}) => _OptionRow(
      key: entry == _highlighted ? _highlightedKey : null,
      option: option,
      pointer: pointer,
      isHighlighted: pointer && entry == _highlighted,
      onHover: () {
        if (_highlighted != entry) setState(() => _highlighted = entry);
      },
    );
    final list = switch ((widget.rows, widget.emptyText)) {
      (null, _) => const Padding(
        padding: EdgeInsets.all(PregoSpacing.x3l),
        child: Center(child: PregoActivityIndicator(color: null)),
      ),
      ([], null) => const SizedBox.shrink(),
      ([], final String text) => _Note(text: text),
      (final List<PregoPickerSearchRow> rows, _) => ListView.builder(
        controller: _scrollController,
        // Still lazy: the popover's height cap bounds the list.
        shrinkWrap: true,
        padding: pointer ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(vertical: 6),
        itemCount: rows.length,
        itemBuilder: (context, index) => switch (rows[index]) {
          PregoPickerSearchHeading(:final text) => _Heading(text: text, pointer: pointer),
          PregoPickerSearchNote(:final text) => _Note(text: text),
          final PregoPickerSearchOption option => optionRow(option: option, entry: rowsStart + index),
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
      // Spread apart, so the footer keeps to the bottom of a body taller than
      // the rows; a body that sizes to them leaves no space between.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header != null) ...[
                  Padding(
                    // The list's own inset, so the header lines up with its rows.
                    padding: pointer ? const EdgeInsets.all(4) : const EdgeInsetsDirectional.only(top: 6),
                    child: optionRow(option: header, entry: 0),
                  ),
                  Divider(height: 1, thickness: 0.5, color: prego.colors.borderSecondary),
                ],
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
          ),
          if (footer != null)
            _Footer(footer: footer, pointer: pointer, isHighlighted: pointer && _highlighted == _footerIndex),
        ],
      ),
    );
  }
}

/// The footer's pill under a hairline. The search field keeps the focus, so
/// the keyboard highlight draws the button's focus ring around it.
class const _Footer({
  required final PregoPickerSearchFooter footer,
  required final bool pointer,
  required final bool isHighlighted,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.borderSecondary, width: 0.5)),
      ),
      child: Padding(
        // Room for the focus ring inside the popover's clip.
        padding: EdgeInsets.all(pointer ? 8 : 12),
        child: Semantics(
          selected: footer.isSelected,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PregoRadius.full),
              boxShadow: isHighlighted
                  ? [
                      BoxShadow(color: colors.focusRing, spreadRadius: 4),
                      BoxShadow(color: colors.bgSurface1, spreadRadius: 2),
                    ]
                  : null,
            ),
            child: PregoButtonsSolid(
              label: footer.label,
              leadingIcon: footer.icon,
              labelTrailing: footer.isSelected
                  ? Icon(TablerRegular.check, size: PregoIconSize.md, color: colors.bgBrandSolid)
                  : null,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: pointer ? PregoButtonsSolidSize.sm : PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: footer.onPick,
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet centred text in the list's place or among its rows.
class const _Note({required final String text}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsets.all(PregoSpacing.x3l),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
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
          mouseCursor: WidgetStateMouseCursor.clickable,
          onTap: option.onPick,
          hoverColor: pointer ? Colors.transparent : null,
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              // The secondary hover grey is lost on the popover surface. Light
              // takes the stronger gray hover; dark, the sidebar's selected tint.
              // A hovering pointer moves this highlight; the ink hover stays clear.
              color: !isHighlighted
                  ? null
                  : Theme.of(context).brightness == Brightness.dark
                  ? prego.colors.textBrandPrimary.withValues(alpha: 0.14)
                  : prego.colors.bgGrayHover,
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
                      Icon(TablerRegular.check, size: PregoIconSize.sm, color: prego.colors.bgBrandSolid),
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
