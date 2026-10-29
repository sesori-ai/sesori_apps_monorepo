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

/// The secondary pills pinned below a [PregoPickerSearchList], which the
/// search does not filter, such as one that clears a filter.
sealed class const PregoPickerSearchFooter() {
  /// One pill across the full width.
  const factory single({required PregoPickerSearchFooterAction action}) = PregoPickerSearchSingleFooter;

  /// Two pills side by side, sharing the width equally. Down from the last
  /// option reaches `leading` first, then `trailing`.
  const factory pair({
    required PregoPickerSearchFooterAction leading,
    required PregoPickerSearchFooterAction trailing,
  }) = PregoPickerSearchPairFooter;
}

class const PregoPickerSearchSingleFooter({required final PregoPickerSearchFooterAction action})
    extends PregoPickerSearchFooter;

class const PregoPickerSearchPairFooter({
  required final PregoPickerSearchFooterAction leading,
  required final PregoPickerSearchFooterAction trailing,
}) extends PregoPickerSearchFooter;

/// A pill of a [PregoPickerSearchFooter]. A check after its label marks it as
/// the current choice.
class const PregoPickerSearchFooterAction({
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
/// scrolls itself, over an optional [footer] the search does not filter.
///
/// Under a pointer the field takes focus, so typing filters at once. Up and
/// Down move a highlight through the options and then the footer's pills, and
/// the mouse moves it across the options; Enter picks the highlighted entry,
/// and Esc closes the picker. The highlight starts on the first matching
/// option, so Enter after typing picks a match, and never on the footer, so
/// with nothing matching Enter picks nothing. Under touch the field waits for
/// a tap, so opening a picker never raises the keyboard over the options.
class const PregoPickerSearchList({
  super.key,
  required final String searchHint,

  /// Receives the trimmed, lowercased query.
  required final ValueChanged<String> onQueryChanged,

  /// Pills pinned below the list, outside its scroll and set off by a
  /// hairline. Down from the last option reaches them. In a body of fixed
  /// height, such as a phone sheet, they sit at the bottom edge, which rides
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

  /// The highlighted option's index in [_rows], or past them the footer pill's
  /// index in [_footerActions] plus their length; null when there is none.
  late int? _highlighted = _firstHighlight();

  List<PregoPickerSearchRow> get _rows => widget.rows ?? const [];

  /// The footer's pills in highlight order, after the rows.
  List<PregoPickerSearchFooterAction> get _footerActions => switch (widget.footer) {
    null => const [],
    PregoPickerSearchSingleFooter(:final action) => [action],
    PregoPickerSearchPairFooter(:final leading, :final trailing) => [leading, trailing],
  };

  /// The first matching option; never a footer pill, so Enter after typing
  /// cannot pick one.
  int? _firstHighlight() {
    final first = _nextOption(after: -1, step: 1);
    return first != null && first < _rows.length ? first : null;
  }

  /// Whether the user moved the highlight since the query last changed.
  bool _moved = false;

  @override
  void didUpdateWidget(PregoPickerSearchList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.rows, widget.rows)) return;
    // Rows that change for the same query, such as late matches added below,
    // keep an option the user moved to, so Enter still picks what they chose.
    final highlighted = _highlighted;
    final oldRows = oldWidget.rows ?? const [];
    if (_moved && highlighted != null) {
      if (highlighted >= oldRows.length) {
        final pill = highlighted - oldRows.length + _rows.length;
        if (pill < _rows.length + _footerActions.length) {
          _highlighted = pill;
          return;
        }
      } else if (_rows.elementAtOrNull(highlighted) is PregoPickerSearchOption) {
        return;
      }
    }
    // New matches start from the top.
    _highlighted = _firstHighlight();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int? _nextOption({required int after, required int step}) {
    final rows = _rows;
    final end = rows.length + _footerActions.length;
    for (var index = after + step; index >= 0 && index < end; index += step) {
      if (index >= rows.length || rows[index] is PregoPickerSearchOption) return index;
    }
    return null;
  }

  void _move({required int step}) {
    // With nothing highlighted, Down still reaches the footer.
    final next = _nextOption(after: _highlighted ?? -1, step: step);
    if (next == null) return;
    _moved = true;
    setState(() => _highlighted = next);
    // The next option neighbours the last one, so the list has built it. The
    // footer's pills carry no key: they are outside the scroll.
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
    final rows = _rows;
    if (highlighted >= rows.length) {
      _footerActions.elementAtOrNull(highlighted - rows.length)?.onPick();
    } else if (rows[highlighted] case final PregoPickerSearchOption option) {
      option.onPick();
    }
  }

  void _setQuery(String value) {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _moved = false;
    widget.onQueryChanged(value.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    final footerActions = _footerActions;
    final highlighted = _highlighted;
    Widget optionRow({required PregoPickerSearchOption option, required int entry}) => _OptionRow(
      key: entry == highlighted ? _highlightedKey : null,
      option: option,
      pointer: pointer,
      isHighlighted: pointer && entry == highlighted,
      onHover: () {
        if (_highlighted == entry) return;
        _moved = true;
        setState(() => _highlighted = entry);
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
          final PregoPickerSearchOption option => optionRow(option: option, entry: index),
        },
      ),
    };

    return CallbackShortcuts(
      bindings: pointer
          ? {
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
                Padding(
                  padding: pointer
                      ? const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 0)
                      : const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 0),
                  // Only around the field: a button Tab focuses takes its own
                  // Enter rather than picking the highlight.
                  child: CallbackShortcuts(
                    bindings: pointer
                        ? {
                            const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(step: 1),
                            const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(step: -1),
                            const SingleActivator(LogicalKeyboardKey.enter): _pickHighlighted,
                            const SingleActivator(LogicalKeyboardKey.numpadEnter): _pickHighlighted,
                          }
                        : const {},
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
                ),
                Flexible(child: list),
              ],
            ),
          ),
          if (footerActions.isNotEmpty)
            _Footer(
              actions: footerActions,
              pointer: pointer,
              highlighted: pointer && highlighted != null ? highlighted - _rows.length : null,
            ),
        ],
      ),
    );
  }
}

/// The footer's pills in one row under a hairline, sharing its width equally.
/// The search field keeps the focus, so the keyboard highlight draws a pill's
/// focus ring around it.
class const _Footer({
  required final List<PregoPickerSearchFooterAction> actions,
  required final bool pointer,

  /// The highlighted pill's index in [actions]; anything else highlights none.
  required final int? highlighted,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    // Room for the focus ring inside the popover's clip and between the pills.
    final gap = pointer ? 8.0 : 12.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.borderSecondary, width: 0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.all(gap),
        child: Row(
          spacing: gap,
          children: [
            for (final (index, action) in actions.indexed)
              Expanded(
                child: Semantics(
                  selected: action.isSelected,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(PregoRadius.full),
                      boxShadow: index == highlighted
                          ? [
                              BoxShadow(color: colors.focusRing, spreadRadius: 4),
                              BoxShadow(color: colors.bgSurface1, spreadRadius: 2),
                            ]
                          : null,
                    ),
                    child: PregoButtonsSolid(
                      label: action.label,
                      leadingIcon: action.icon,
                      labelTrailing: action.isSelected
                          ? Icon(TablerRegular.check, size: PregoIconSize.md, color: colors.bgBrandSolid)
                          : null,
                      hierarchy: PregoButtonsSolidHierarchy.secondary,
                      size: pointer ? PregoButtonsSolidSize.sm : PregoButtonsSolidSize.lg,
                      fullWidth: true,
                      onPressed: action.onPick,
                    ),
                  ),
                ),
              ),
          ],
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
