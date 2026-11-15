import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../utils/copy_text_to_clipboard.dart";

/// A transcript message's menu, opened by long-pressing the message under a
/// finger or right-clicking it with a mouse ([PregoContextMenu]).
///
/// It ends with Copy and Select text. Copy copies the text selected inside the
/// message when there is some, and otherwise [copyText]. Select text selects
/// all of the message's text, with the handles and toolbar a long-press
/// selection had. The message's own actions go before them.
class const TranscriptMessageMenu({
  super.key,

  /// What Copy copies when nothing inside the message is selected: the
  /// message's text as Markdown, or null when it has none.
  required final String? copyText,

  /// Builds the message, handing its text's selection area the key the menu
  /// reads and selects it through.
  required final Widget Function(BuildContext context, GlobalKey<PregoReadableSelectionAreaState> selectionArea)
  builder,
}) extends StatefulWidget {
  /// Wide enough for the longest item ("Select text") at the larger text
  /// sizes, without spanning the message it is anchored to.
  static const double _menuWidth = 220;

  @override
  State<TranscriptMessageMenu> createState() => _TranscriptMessageMenuState();
}

class _TranscriptMessageMenuState() extends State<TranscriptMessageMenu> {
  final _selectionArea = GlobalKey<PregoReadableSelectionAreaState>();

  @override
  Widget build(BuildContext context) => PregoContextMenu(
    menuWidth: TranscriptMessageMenu._menuWidth,
    // Holds the message sharp while the rest of the transcript blurs back.
    spotlight: PregoMenuSpotlight.listRow,
    entriesBuilder: _entries,
    builder: (context, _) => widget.builder(context, _selectionArea),
  );

  List<PregoMenuEntry> _entries() {
    final loc = context.loc;
    final area = _selectionArea.currentState;
    final copyText = area?.selectedText ?? widget.copyText;
    return [
      if (copyText != null)
        PregoMenuItem(
          leadingIcon: TablerRegular.copy,
          title: loc.sessionDetailCopy,
          subtitle: null,
          isSelected: false,
          shortcutLabel: null,
          onTap: () => unawaited(_copy(text: copyText)),
        ),
      if (area != null)
        PregoMenuItem(
          leadingIcon: TablerRegular.cursor_text,
          title: loc.sessionDetailSelectText,
          subtitle: null,
          isSelected: false,
          shortcutLabel: null,
          onTap: _selectText,
        ),
    ];
  }

  Future<void> _copy({required String text}) async {
    if (!await copyTextToClipboard(text: text, operation: "transcript message") || !mounted) return;
    PregoPopupAlertPresenter.of(context).show(
      title: context.loc.sessionDetailMessageCopied,
      variant: PregoPopupAlertsNotificationsVariant.success,
    );
  }

  /// Selects once the menu has closed: closing hands the focus back to what
  /// had it, which would clear a selection made before.
  void _selectText() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _selectionArea.currentState?.selectAll();
  });
}
