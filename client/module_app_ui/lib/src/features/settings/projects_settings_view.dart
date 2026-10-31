import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../project_list/add_project_dialog.dart";
import "../project_list/project_menu_entries.dart";
import "../project_list/project_path_labels.dart";
import "widgets/settings_window_page.dart";

/// Vertical inset between the nav bar and the list.
const double _contentTopPadding = 10.0;

/// How far the rows dim while no bridge is connected, as the bridge settings do.
const double _offlineRowsOpacity = 0.4;

const Duration _offlineTransition = Duration(milliseconds: 200);

/// The connected computer's projects, each with the project list's actions
/// (rename, hide, remove a missing one) behind a "⋯" button or a secondary
/// click, under "Open another folder…", which adds one.
///
/// Reads the live list from the [ProjectListCubit] the session scope
/// provides. Offline, one line says why and the rows dim and stop acting.
class const ProjectsSettingsView({super.key, required final SettingsPageChrome chrome}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final state = context.watch<ProjectListCubit>().state;
    final online = context.select(
      (ConnectionOverlayCubit cubit) => switch (cubit.state) {
        ConnectionOverlayHidden(:final connected) => connected,
        ConnectionOverlayReconnecting() ||
        ConnectionOverlayConnectionLost() ||
        ConnectionOverlayBridgeOffline() => false,
      },
    );
    // "No project" is the bridge's own, with no folder to rename or hide.
    final projects = switch (state) {
      ProjectListLoaded(:final folderProjects) => folderProjects,
      ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => const <ProjectSummary>[],
    };
    String nameOf(ProjectSummary project) => projectDisplayName(loc: loc, project: project);
    final pathLabels = projectPathLabels(projects: projects, nameOf: nameOf);
    final status = switch (state) {
      ProjectListLoading() => PregoGroupedRow(
        icon: TablerRegular.folder,
        title: Text(loc.projectListLoadingSemantics),
        trailing: const PregoActivityIndicator(color: null),
      ),
      ProjectListFailed() => PregoGroupedRow(
        icon: TablerRegular.alert_circle,
        title: Text(loc.projectListErrorTitle),
        trailing: PregoButtonsSolid(
          label: loc.projectListRetry,
          hierarchy: PregoButtonsSolidHierarchy.secondary,
          size: PregoButtonsSolidSize.sm,
          onPressed: online ? () => unawaited(context.read<ProjectListCubit>().retryLoadProjects()) : null,
        ),
      ),
      ProjectListLoaded() || ProjectListBridgeDisconnected() => null,
    };
    final duration = context.isReducedMotion ? Duration.zero : _offlineTransition;
    final offlineLine = online
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.md),
            child: Text(
              loc.settingsProjectsOffline,
              style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
            ),
          );
    return SettingsChromePage(
      chrome: chrome,
      onRefresh: null,
      slivers: [
        SliverPadding(
          padding: EdgeInsetsDirectional.fromSTEB(
            PregoSpacing.xl,
            _contentTopPadding,
            PregoSpacing.xl,
            PregoSpacing.xl + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The line eases in and out, so the rows below it glide rather
                // than jump when the bridge drops or returns. Under reduced
                // motion no wrapper at all: a zero-length AnimatedSize would
                // re-dirty itself mid-layout.
                context.isReducedMotion
                    ? offlineLine
                    : AnimatedSize(
                        duration: duration,
                        alignment: AlignmentDirectional.topStart,
                        child: offlineLine,
                      ),
                AnimatedOpacity(
                  opacity: online ? 1 : _offlineRowsOpacity,
                  duration: duration,
                  child: PregoGroupedRows(
                    children: [
                      PregoGroupedRowPosition(
                        isLast: status == null && projects.isEmpty,
                        child: PregoGroupedRow(
                          key: const Key("projects-settings-open-folder"),
                          icon: TablerRegular.folder_plus,
                          title: Text(loc.settingsProjectsOpenFolder),
                          // The added project's row enters the list below.
                          onTap: online
                              ? () => unawaited(
                                  showAddProjectDialog(
                                    context: context,
                                    onProjectAdded: ({required context, required project, required displayName}) {},
                                  ),
                                )
                              : null,
                        ),
                      ),
                      if (status != null) PregoGroupedRowPosition(isLast: true, child: status),
                      // A hidden row closes while the rows below it rise into
                      // its place; the rows above it stay still.
                      PregoAnimatedList<ProjectSummary>(
                        items: projects,
                        itemKey: (project) => ValueKey(project.id),
                        itemBuilder: (context, index, project) => PregoGroupedRowPosition(
                          isLast: index == projects.length - 1,
                          child: _ProjectRow(
                            key: ValueKey("projects-settings-row-${project.id}"),
                            project: project,
                            displayName: nameOf(project),
                            pathLabel: pathLabels[project.id] ?? project.path,
                            online: online,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One project: its name over its path, or over "Folder not found" once the
/// folder is gone.
class const _ProjectRow({
  super.key,
  required final ProjectSummary project,
  required final String displayName,
  required final String pathLabel,
  required final bool online,
}) extends StatelessWidget {
  /// Wide enough for the longest action label.
  static const double _menuWidth = 200;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    List<PregoMenuEntry> entries() => projectMenuEntries(context: context, project: project);
    // Flat panels, as a glass popup would morph out of the whole row. A
    // secondary click anywhere on the row drops this one from the pointer.
    return PregoAnchorMenu(
      flat: true,
      acquireOpenLease: null,
      menuWidth: _menuWidth,
      entriesBuilder: entries,
      triggerBuilder: (context, openRowMenu) => GestureDetector(
        onSecondaryTap: online ? openRowMenu : null,
        child: PregoGroupedRow(
          icon: TablerRegular.folder,
          title: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: project.directoryMissing
              ? Text(
                  loc.projectListFolderNotFound,
                  style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textWarningPrimary),
                )
              : Text(pathLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
          // The "⋯" button hangs the same menu off itself.
          trailing: PregoAnchorMenu(
            flat: true,
            placement: PregoMenuPlacement.belowRightAligned,
            acquireOpenLease: null,
            menuWidth: _menuWidth,
            entriesBuilder: entries,
            triggerBuilder: (context, openMenu) => PregoButtonsSolid.iconOnly(
              key: ValueKey("projects-settings-actions-${project.id}"),
              leadingIcon: TablerRegular.dots,
              semanticLabel: loc.settingsProjectActions(displayName),
              showsTooltip: true,
              hierarchy: PregoButtonsSolidHierarchy.tertiary,
              size: PregoButtonsSolidSize.sm,
              onPressed: online ? openMenu : null,
            ),
          ),
        ),
      ),
    );
  }
}
