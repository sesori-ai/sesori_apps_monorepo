import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../utils/copy_text_to_clipboard.dart";

/// Tells the transcript that a message's menu opened, or has closed, so it can
/// hold the message still under the menu meanwhile.
class const TranscriptMessageMenuOpenChanged({required final bool open}) extends Notification;

/// A transcript message's menu, opened by long-pressing the message under a
/// finger or right-clicking it with a mouse ([PregoContextMenu]).
///
/// It ends with Copy and Select text. Copy copies the text selected inside the
/// message when there is some, and otherwise [copyText]. Select text selects
/// all of the message's text, with the handles and toolbar a long-press
/// selection had, when the message hands its selection area the key. The
/// message's own actions go before them.
class const TranscriptMessageMenu({
  super.key,

  /// What Copy copies when nothing inside the message is selected: the
  /// message's text as Markdown, or null while it has none (a reply whose
  /// text has not arrived keeps its menu, so the reply is never rebuilt).
  required final String? copyText,

  /// The sharp cut-out a long-press menu keeps around the message.
  required final PregoMenuSpotlight spotlight,

  /// Builds the message, handing its text's selection area the key the menu
  /// reads and selects it through.
  required final Widget Function(BuildContext context, GlobalKey<PregoReadableSelectionAreaState> selectionArea)
  builder,
}) extends StatefulWidget {
  /// Wide enough for the longest item ("Select text") at the larger text
  /// sizes, without spanning the message it is anchored to.
  static const double _menuWidth = 220;

  /// The message [builder] builds, with its menu when it has [text] to copy,
  /// and without one when it has none: nothing in it could be copied.
  static Widget wrap({
    required PregoMenuSpotlight spotlight,
    required String? text,
    required Widget Function(GlobalKey<PregoReadableSelectionAreaState>? selectionArea) builder,
  }) {
    if (text == null || text.isEmpty) return builder(null);
    return TranscriptMessageMenu(
      spotlight: spotlight,
      copyText: text,
      builder: (context, selectionArea) => builder(selectionArea),
    );
  }

  @override
  State<TranscriptMessageMenu> createState() => _TranscriptMessageMenuState();
}

class _TranscriptMessageMenuState() extends State<TranscriptMessageMenu> {
  final _selectionArea = GlobalKey<PregoReadableSelectionAreaState>();

  @override
  Widget build(BuildContext context) => PregoContextMenu(
    menuWidth: TranscriptMessageMenu._menuWidth,
    // Holds the message sharp while the rest of the transcript blurs back.
    spotlight: widget.spotlight,
    onOpenChanged: (open) => TranscriptMessageMenuOpenChanged(open: open).dispatch(context),
    entriesBuilder: _entries,
    builder: (context, _) => widget.builder(context, _selectionArea),
  );

  List<PregoMenuEntry> _entries() {
    final loc = context.loc;
    final area = _selectionArea.currentState;
    final copyText = area?.selectedText ?? widget.copyText;
    return [
      if (copyText != null && copyText.isNotEmpty)
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
