import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../project_list/widgets/project_tile.dart";

typedef NewSessionProjectSelected = void Function({required String projectId, required String projectName});

/// The new session page's opening: what the page is for, and which project the
/// session starts in. The selector opens only when there is another project to
/// choose.
class const NewSessionHeader({
  super.key,
  required final String projectId,
  required final String? projectName,
  required final List<ProjectSummary> projects,
  required final NewSessionProjectSelected onProjectSelected,
  required final Widget? harness,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final canSwitch = projects.any((project) => project.id != projectId);
    // The loaded list knows the current name; the route's can be missing or stale.
    final current = projects.where((project) => project.id == projectId).firstOrNull;
    final label = current == null
        ? projectName ?? loc.projectListDefaultName
        : projectDisplayName(loc: loc, project: current);
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
            PregoAnchorMenu(
              flat: true,
              menuWidth: 260,
              acquireOpenLease: null,
              entriesBuilder: () => [
                for (final project in projects)
                  PregoMenuItem(
                    title: projectDisplayName(loc: loc, project: project),
                    subtitle: null,
                    isSelected: project.id == projectId,
                    shortcutLabel: null,
                    leadingIcon: TablerRegular.folder,
                    isEnabled: true,
                    onTap: () {
                      if (project.id == projectId) return;
                      onProjectSelected(
                        projectId: project.id,
                        projectName: projectDisplayName(loc: loc, project: project),
                      );
                    },
                  ),
              ],
              triggerBuilder: (context, openMenu) => PregoButtonsSolid(
                key: const Key("new_session_project"),
                label: label,
                leadingIcon: TablerRegular.folder,
                trailingIcon: canSwitch ? TablerRegular.chevron_down : null,
                hierarchy: PregoButtonsSolidHierarchy.secondary,
                size: PregoButtonsSolidSize.sm,
                onPressed: canSwitch ? openMenu : null,
              ),
            ),
            ?harness,
          ],
        ),
      ],
    );
  }
}
