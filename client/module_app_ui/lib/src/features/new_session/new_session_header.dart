import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../project_list/widgets/project_tile.dart";
import "../project_picker/project_picker.dart";

/// [projectId]'s name in the live project list, which knows a rename the
/// route's [projectName] can miss.
String liveProjectName({required BuildContext context, required String projectId, required String? projectName}) {
  final loc = context.loc;
  final current = context.select(
    (ProjectListCubit cubit) => switch (cubit.state) {
      ProjectListLoaded(:final projects) => projects.where((project) => project.id == projectId).firstOrNull,
      ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => null,
    },
  );
  return current == null ? projectName ?? loc.projectListDefaultName : projectDisplayName(loc: loc, project: current);
}

/// The new session page's opening: what the page is for, and which project the
/// session starts in. With [onProjectSelected] the project opens the picker;
/// without it the header only names the project.
class const NewSessionHeader({
  super.key,
  required final String projectId,
  required final String? projectName,
  required final NewSessionProjectSelected? onProjectSelected,
  required final Widget? harness,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final onProjectSelected = this.onProjectSelected;
    final label = onProjectSelected == null
        ? projectName ?? loc.projectListDefaultName
        : liveProjectName(context: context, projectId: projectId, projectName: projectName);
    Widget pill({required VoidCallback? onPressed}) => PregoButtonsSolid(
      key: const Key("new_session_project"),
      label: label,
      leadingIcon: TablerRegular.folder,
      trailingIcon: onPressed == null ? null : TablerRegular.chevron_down,
      hierarchy: PregoButtonsSolidHierarchy.secondary,
      size: PregoButtonsSolidSize.sm,
      onPressed: onPressed,
    );
    return Column(
      spacing: PregoSpacing.lg,
      children: [
        Text(
          loc.newSessionHeading,
          textAlign: TextAlign.center,
          style: prego.textTheme.displayXs.bold.copyWith(color: prego.colors.textPrimary),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: PregoSpacing.md,
          runSpacing: PregoSpacing.md,
          children: [
            if (onProjectSelected == null)
              pill(onPressed: null)
            else
              ProjectPicker(
                selectedProjectId: projectId,
                onSelected: onProjectSelected,
                onAllProjects: null,
                triggerBuilder: (_, open) => pill(onPressed: open),
              ),
            ?harness,
          ],
        ),
      ],
    );
  }
}
