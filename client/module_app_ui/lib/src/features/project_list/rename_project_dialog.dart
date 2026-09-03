import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/rename_sheet.dart";

Future<void> showRenameProjectDialog({
  required BuildContext context,
  required ProjectSummary project,
  required ProjectListCubit cubit,
}) {
  return showPregoBottomSheet<void>(
    context: context,
    title: context.loc.renameProjectTitle,
    builder: (_) => RenameProjectDialog(project: project, cubit: cubit),
  );
}

@visibleForTesting
class const RenameProjectDialog({
  required final ProjectSummary project,
  required final ProjectListCubit cubit,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return RenameSheet(
      initialValue: project.name ?? "",
      hintText: loc.renameProjectHint,
      saveLabel: loc.renameSave,
      successMessage: loc.renameProjectSuccess,
      failureMessage: loc.renameProjectFailed,
      actionHeight: 48,
      onRename: (name) => cubit.renameProject(projectId: project.id, name: name),
    );
  }
}
