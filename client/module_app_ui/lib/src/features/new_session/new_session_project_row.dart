import "dart:math" as math;

import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";
import "../project_list/widgets/project_tile.dart";

typedef NewSessionProjectSelected = void Function({required String projectId, required String projectName});

/// What to call the project a new session starts in. The loaded list knows the
/// current name; the route's can be missing or stale.
String newSessionProjectLabel({
  required AppLocalizations loc,
  required String projectId,
  required String? projectName,
  required List<ProjectSummary> projects,
}) {
  final current = projects.where((project) => project.id == projectId).firstOrNull;
  return current == null ? projectName ?? loc.projectListDefaultName : projectDisplayName(loc: loc, project: current);
}

/// Widest a new session row's value may grow before it ellipsizes: 200 px, or
/// less on a narrow phone, so a long name never crowds out the row's label.
double newSessionRowValueMaxWidth(BuildContext context) => math.min(200, MediaQuery.sizeOf(context).width * 0.4);

/// The new session card's first row: which project the session starts in. The
/// row opens a project menu only when there is another project to choose.
class const NewSessionProjectRow({
  super.key,
  required final String projectId,
  required final String? projectName,
  required final List<ProjectSummary> projects,
  required final NewSessionProjectSelected onProjectSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final canSwitch = projects.any((project) => project.id != projectId);
    final label = newSessionProjectLabel(
      loc: loc,
      projectId: projectId,
      projectName: projectName,
      projects: projects,
    );
    return PregoAnchorMenu(
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
      triggerBuilder: (context, openMenu) => MergeSemantics(
        child: Semantics(
          button: canSwitch,
          child: PregoGroupedRow(
            key: const Key("new_session_project"),
            title: Text(loc.newSessionProjectLabel),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: PregoSpacing.xs,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: newSessionRowValueMaxWidth(context)),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
                  ),
                ),
                if (canSwitch) const Icon(TablerRegular.chevron_right),
              ],
            ),
            onTap: canSwitch ? openMenu : null,
          ),
        ),
      ),
    );
  }
}
