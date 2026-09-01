import "package:flutter/foundation.dart" show kIsWeb;
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/module_prego.dart";

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
    return showPregoBottomSheet<void>(
      context: context,
      title: context.loc.sessionDetailEditorTitle,
      bodySize: PregoBottomSheetBodySize.full,
      builder: (_) => PromptEditorSheet(
        controller: controller,
        placeholder: placeholder,
        pasteAction: pasteAction,
        contextMenuBuilder: contextMenuBuilder,
      ),
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
