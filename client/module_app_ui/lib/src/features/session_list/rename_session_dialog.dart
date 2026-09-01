import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/rename_sheet.dart";

Future<void> showRenameSessionDialog({
  required BuildContext context,
  required Session session,
  required SessionListCubit cubit,
}) {
  return showPregoBottomSheet<void>(
    context: context,
    title: context.loc.renameSessionTitle,
    builder: (_) {
      final loc = context.loc;
      return RenameSheet(
        initialValue: session.title ?? "",
        hintText: loc.renameSessionHint,
        saveLabel: loc.renameSave,
        successMessage: loc.renameSessionSuccess,
        failureMessage: loc.renameSessionFailed,
        submitOnEnter: true,
        onRename: (title) => cubit.renameSession(sessionId: session.id, title: title),
      );
    },
  );
}
