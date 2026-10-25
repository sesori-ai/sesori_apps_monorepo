import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "rename_project_dialog.dart";

/// A project's actions: rename, and hide (or remove, once its folder is gone).
/// [PregoAnchorMenu] dismisses the menu before running an entry's `onTap`, so
/// both act against the still-mounted row rather than a popped route.
List<PregoMenuEntry> projectMenuEntries({required BuildContext context, required ProjectSummary project}) {
  final loc = context.loc;
  return [
    PregoMenuItem(
      leadingIcon: TablerRegular.pencil,
      title: loc.rename,
      subtitle: null,
      isSelected: false,
      shortcutLabel: null,
      onTap: () => unawaited(
        showRenameProjectDialog(context: context, project: project, cubit: context.read<ProjectListCubit>()),
      ),
    ),
    PregoMenuItem(
      leadingIcon: TablerRegular.eye_off,
      // A project whose folder is gone has nothing left to come back to.
      title: project.directoryMissing ? loc.projectListRemove : loc.hideProject,
      subtitle: null,
      isSelected: false,
      shortcutLabel: null,
      onTap: () => unawaited(_hideProject(context: context, project: project)),
    ),
  ];
}

/// A confirmed hide drops the project from the list, which disposes its row,
/// so the presenter and strings are resolved before the cubit call.
Future<void> _hideProject({required BuildContext context, required ProjectSummary project}) async {
  final popupAlertPresenter = PregoPopupAlertPresenter.of(context);
  final loc = context.loc;
  final hidden = await context.read<ProjectListCubit>().hideProject(projectId: project.id);
  popupAlertPresenter.show(
    title: hidden ? loc.projectHidden : loc.projectHideFailed,
    variant: hidden ? PregoPopupAlertsNotificationsVariant.success : PregoPopupAlertsNotificationsVariant.error,
  );
}
