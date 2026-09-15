import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

/// Desktop navigation frame. Its project inventory is shared with the main pane.
class const DesktopSidebar({
  super.key,
  required final bool collapsed,
  required final bool autoCollapsed,
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
              selected: false,
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
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    final basename = projectDirectoryBasename(project);
                    final name = project.name ?? (basename.isEmpty ? loc.projectListDefaultName : basename);
                    return _SidebarButton(
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
                  onPressed: () => unawaited(context.read<ProjectListCubit>().refreshProjects()),
                ),
                ProjectListBridgeDisconnected() => const SizedBox.shrink(),
              },
            ),
            _SidebarButton(
              label: loc.desktopBridgeTitle,
              icon: const Icon(TablerRegular.server, size: 20),
              collapsed: collapsed,
              selected: false,
              onPressed: onOpenBridge,
            ),
            _SidebarButton(
              label: loc.settingsTitle,
              icon: const Icon(TablerRegular.settings, size: 20),
              collapsed: collapsed,
              selected: false,
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
