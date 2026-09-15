import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

/// Current top-level route; project detail routes also select their project row.
enum DesktopCockpitDestination() {
  bridge,
  projects,
  settings,
}

/// Desktop navigation frame. Its project inventory is shared with the main pane.
class const DesktopSidebar({
  super.key,
  required final double expansion,
  required final bool autoCollapsed,
  required final DesktopCockpitDestination destination,
  required final String? selectedProjectId,
  required final VoidCallback onToggleCollapsed,
  required final VoidCallback onOpenProjects,
  required final VoidCallback onAddProject,
  required final ProjectOpenedCallback onOpenProject,
  required final VoidCallback onOpenBridge,
  required final VoidCallback onOpenSettings,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectListCubit>().state;
    final loc = context.loc;
    final prego = context.prego;
    return Material(
      color: prego.colors.bgSecondary,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 8),
              child: Row(
                children: [
                  if (expansion > 0)
                    Expanded(
                      child: ClipRect(
                        child: Opacity(
                          opacity: expansion,
                          child: SizedBox(
                            height: 32,
                            child: OverflowBox(
                              alignment: AlignmentDirectional.centerStart,
                              minWidth: 130,
                              maxWidth: 130,
                              child: Semantics(
                                button: true,
                                label: loc.projectListTitle,
                                onTap: onOpenProjects,
                                excludeSemantics: true,
                                selected:
                                    destination == DesktopCockpitDestination.projects && selectedProjectId == null,
                                child: TextButton(
                                  onPressed: onOpenProjects,
                                  style: TextButton.styleFrom(
                                    alignment: AlignmentDirectional.centerStart,
                                    padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.sm),
                                  ),
                                  child: Text(
                                    loc.projectListTitle,
                                    style: prego.textTheme.textSm.bold.copyWith(package: "theme_prego"),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      key: const Key("desktop-sidebar-toggle"),
                      tooltip: expansion < 0.5 ? loc.desktopSidebarExpand : loc.desktopSidebarCollapse,
                      padding: const EdgeInsets.all(PregoSpacing.sm),
                      onPressed: autoCollapsed ? null : onToggleCollapsed,
                      icon: Icon(
                        expansion < 0.5
                            ? TablerRegular.layout_sidebar_left_expand
                            : TablerRegular.layout_sidebar_left_collapse,
                        size: 18,
                        color: autoCollapsed ? prego.colors.textDisabled : prego.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 16),
              child: Tooltip(
                message: loc.desktopSidebarNewProject,
                child: FilledButton(
                  key: const Key("desktop-sidebar-new-project"),
                  onPressed: state is ProjectListLoaded ? onAddProject : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: prego.colors.bgBrandSolid,
                    foregroundColor: prego.colors.textWhite,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.sm),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PregoRadius.lg)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(TablerRegular.plus, size: 18),
                      if (expansion > 0)
                        Flexible(
                          child: Opacity(
                            opacity: expansion,
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(start: PregoSpacing.md * expansion),
                              child: Text(
                                loc.desktopSidebarNewProject,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: prego.textTheme.textSm.medium.copyWith(
                                  color: prego.colors.textWhite,
                                  package: "theme_prego",
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: switch (state) {
                ProjectListLoading() => Center(
                  child: Semantics(
                    label: loc.projectListLoadingSemantics,
                    child: const PregoActivityIndicator(color: null),
                  ),
                ),
                ProjectListLoaded(:final projects, :final activityById, :final unseenByProjectId) => ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: projects.length,
                  findChildIndexCallback: (key) {
                    final index = projects.indexWhere((project) => ValueKey(project.id) == key);
                    return index < 0 ? null : index;
                  },
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    final basename = projectDirectoryBasename(project);
                    final name = project.name ?? (basename.isEmpty ? loc.projectListDefaultName : basename);
                    final active = activityById[project.id] ?? 0;
                    final unseen = unseenByProjectId[project.id] ?? project.hasUnseenChanges;
                    return _SidebarButton(
                      key: ValueKey(project.id),
                      label: name,
                      icon: PregoAvatarInitials(label: name, size: 26),
                      expansion: expansion,
                      selected: project.id == selectedProjectId,
                      status: active > 0 || unseen
                          ? (
                              icon: PregoAiLoader(size: 18, animate: active > 0),
                              label: active > 0
                                  ? unseen
                                        ? "${loc.projectListRunning(active)}, ${loc.projectListNewActivity}"
                                        : loc.projectListRunning(active)
                                  : loc.projectListNewActivity,
                            )
                          : null,
                      onPressed: () => onOpenProject(context: context, project: project, displayName: name),
                    );
                  },
                ),
                ProjectListFailed() => _SidebarButton(
                  label: loc.projectListRetry,
                  icon: const Icon(TablerRegular.refresh, size: 20),
                  expansion: expansion,
                  selected: false,
                  status: null,
                  onPressed: () => unawaited(context.read<ProjectListCubit>().retryLoadProjects()),
                ),
                ProjectListBridgeDisconnected() => const SizedBox.shrink(),
              },
            ),
            Container(
              key: const Key("desktop-sidebar-footer"),
              padding: const EdgeInsets.symmetric(vertical: PregoSpacing.md),
              decoration: BoxDecoration(
                color: prego.colors.bgSurface1,
                border: Border(top: BorderSide(color: prego.colors.borderPrimary)),
              ),
              child: Column(
                children: [
                  _SidebarButton(
                    label: loc.desktopBridgeTitle,
                    icon: const Icon(TablerRegular.server, size: 20),
                    expansion: expansion,
                    selected: destination == DesktopCockpitDestination.bridge,
                    status: null,
                    onPressed: onOpenBridge,
                  ),
                  _SidebarButton(
                    label: loc.settingsTitle,
                    icon: const Icon(TablerRegular.settings, size: 20),
                    expansion: expansion,
                    selected: destination == DesktopCockpitDestination.settings,
                    status: null,
                    onPressed: onOpenSettings,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const _SidebarButton({
  super.key,
  required final String label,
  required final Widget icon,
  required final double expansion,
  required final bool selected,
  required final ({Widget icon, String label})? status,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final status = this.status;
    final description = status == null ? label : "$label, ${status.label}";
    final emphasized = selected || status != null;
    final color = emphasized ? prego.colors.textPrimary : prego.colors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.md, vertical: PregoSpacing.xxs),
      child: Tooltip(
        message: description,
        child: Semantics(
          button: true,
          selected: selected,
          label: description,
          onTap: onPressed,
          excludeSemantics: true,
          child: InkWell(
            onTap: onPressed,
            hoverColor: prego.colors.bgSecondaryHover,
            focusColor: prego.colors.textBrandPrimary.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(PregoRadius.lg),
            child: Ink(
              decoration: BoxDecoration(
                color: selected ? prego.colors.textBrandPrimary.withValues(alpha: 0.14) : null,
                borderRadius: BorderRadius.circular(PregoRadius.lg),
              ),
              padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.sm, vertical: PregoSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        IconTheme(
                          data: IconThemeData(color: color),
                          child: icon,
                        ),
                        if (status != null && expansion < 1)
                          PositionedDirectional(
                            end: -4,
                            top: -4,
                            child: Opacity(
                              opacity: 1 - expansion,
                              child: DecoratedBox(
                                decoration: BoxDecoration(color: prego.colors.bgSecondary, shape: BoxShape.circle),
                                child: status.icon,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (expansion > 0)
                    Expanded(
                      child: Opacity(
                        opacity: expansion,
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(start: PregoSpacing.md * expansion),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: (emphasized ? prego.textTheme.textSm.medium : prego.textTheme.textSm.regular)
                                .copyWith(color: color, package: "theme_prego"),
                          ),
                        ),
                      ),
                    ),
                  if (status != null && expansion > 0)
                    SizedBox(
                      width: 24 * expansion,
                      height: 20,
                      child: ClipRect(
                        child: Opacity(
                          opacity: expansion,
                          child: OverflowBox(minWidth: 24, maxWidth: 24, child: status.icon),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
