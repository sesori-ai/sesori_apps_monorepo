import "dart:math" as math;

import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";

/// Fullscreen editor for the composer text, opened from the composer's
/// expand button so long prompts can be read and edited comfortably.
///
/// Shares the composer's [TextEditingController], so edits flow straight back
/// into the inline field; dismissing the sheet returns to the composer with
/// the text (and any in-progress draft persistence) untouched.
class const PromptEditorSheet({
  super.key,
  required final TextEditingController controller,
  required final String placeholder,
  required final Action<PasteTextIntent> pasteAction,
  required final EditableTextContextMenuBuilder contextMenuBuilder,
}) extends StatelessWidget {
  static Future<void> show(
    BuildContext context, {
    required TextEditingController controller,
    required String placeholder,
    required Action<PasteTextIntent> pasteAction,
    required EditableTextContextMenuBuilder contextMenuBuilder,
  }) {
    // Status-bar inset, captured before presenting: the modal route strips
    // the top inset from both `padding` and `viewPadding`, so inside the
    // sheet it reads as 0.
    final topInset = MediaQuery.paddingOf(context).top;
    return showPregoBottomSheet<void>(
      context: context,
      title: context.loc.sessionDetailEditorTitle,
      builder: (sheetContext) {
        // Fill the space between the status bar and the keyboard so the sheet
        // always rises to full height; the field hosts its own scrolling, so
        // it needs this bounded height (the sheet re-adds the keyboard inset
        // below the body).
        final screenHeight = MediaQuery.heightOf(sheetContext);
        final keyboard = MediaQuery.viewInsetsOf(sheetContext).bottom;
        final height = screenHeight - topInset - PregoBottomSheet.contentTopInset - keyboard;
        return SizedBox(
          height: math.max(height, screenHeight * 0.3),
          child: PromptEditorSheet(
            controller: controller,
            placeholder: placeholder,
            pasteAction: pasteAction,
            contextMenuBuilder: contextMenuBuilder,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Actions(
      actions: kIsWeb ? const {} : {PasteTextIntent: pasteAction},
      child: TextField(
        controller: controller,
        autofocus: true,
        expands: true,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        contextMenuBuilder: contextMenuBuilder,
        style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: placeholder,
          hintStyle: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
        ),
      ),
    );
  }
}
