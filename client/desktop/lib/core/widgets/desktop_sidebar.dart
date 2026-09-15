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
  required final bool collapsed,
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
    return Material(
      color: context.prego.colors.bgSecondary,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            _SidebarButton(
              label: "Sesori",
              icon: const Icon(TablerRegular.code, size: 24),
              collapsed: collapsed,
              selected: destination == DesktopCockpitDestination.projects && selectedProjectId == null,
              onPressed: onOpenProjects,
            ),
            Flex(
              direction: collapsed ? Axis.vertical : Axis.horizontal,
              children: [
                IconButton(
                  key: const Key("desktop-sidebar-toggle"),
                  tooltip: collapsed ? loc.desktopSidebarExpand : loc.desktopSidebarCollapse,
                  onPressed: autoCollapsed ? null : onToggleCollapsed,
                  icon: Icon(
                    collapsed ? TablerRegular.layout_sidebar_left_expand : TablerRegular.layout_sidebar_left_collapse,
                  ),
                ),
                if (!collapsed)
                  Expanded(child: Text(loc.projectListTitle, style: context.prego.textTheme.textXs.medium)),
                IconButton(
                  tooltip: loc.projectsEmptyAddProject,
                  onPressed: state is ProjectListLoaded ? onAddProject : null,
                  icon: const Icon(TablerRegular.plus, size: 20),
                ),
              ],
            ),
            Expanded(
              child: switch (state) {
                ProjectListLoading() => Center(
                  child: Semantics(
                    label: loc.projectListLoadingSemantics,
                    child: const PregoActivityIndicator(color: null),
                  ),
                ),
                ProjectListLoaded(:final projects) => ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: PregoSpacing.sm),
                  itemCount: projects.length,
                  findChildIndexCallback: (key) {
                    final index = projects.indexWhere((project) => ValueKey(project.id) == key);
                    return index < 0 ? null : index;
                  },
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    final basename = projectDirectoryBasename(project);
                    final name = project.name ?? (basename.isEmpty ? loc.projectListDefaultName : basename);
                    return _SidebarButton(
                      key: ValueKey(project.id),
                      label: name,
                      icon: PregoAvatarInitials(label: name),
                      collapsed: collapsed,
                      selected: project.id == selectedProjectId,
                      onPressed: () => onOpenProject(context: context, project: project, displayName: name),
                    );
                  },
                ),
                ProjectListFailed() => _SidebarButton(
                  label: loc.projectListRetry,
                  icon: const Icon(TablerRegular.refresh),
                  collapsed: collapsed,
                  selected: false,
                  onPressed: () => unawaited(context.read<ProjectListCubit>().retryLoadProjects()),
                ),
                ProjectListBridgeDisconnected() => const SizedBox.shrink(),
              },
            ),
            _SidebarButton(
              label: loc.desktopBridgeTitle,
              icon: const Icon(TablerRegular.server, size: 20),
              collapsed: collapsed,
              selected: destination == DesktopCockpitDestination.bridge,
              onPressed: onOpenBridge,
            ),
            _SidebarButton(
              label: loc.settingsTitle,
              icon: const Icon(TablerRegular.settings, size: 20),
              collapsed: collapsed,
              selected: destination == DesktopCockpitDestination.settings,
              onPressed: onOpenSettings,
            ),
            const SizedBox(height: PregoSpacing.sm),
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
  required final bool collapsed,
  required final bool selected,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xs, vertical: PregoSpacing.xxs),
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          onTap: onPressed,
          excludeSemantics: true,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(PregoRadius.md),
            child: Ink(
              decoration: BoxDecoration(
                color: selected ? context.prego.colors.bgSecondaryHover : null,
                borderRadius: BorderRadius.circular(PregoRadius.md),
              ),
              padding: const EdgeInsets.all(PregoSpacing.sm),
              child: Row(
                mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  icon,
                  if (!collapsed) ...[
                    const SizedBox(width: PregoSpacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.prego.textTheme.textSm.medium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
