import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/session_sidebar/session_sidebar_shell.dart";
import "../project_list/add_project_dialog.dart";
import "../project_list/project_path_labels.dart";

typedef NewSessionProjectSelected = void Function({required String projectId, required String projectName});

/// Chooses a project from the live list, searchable by name and path: a
/// bottom sheet on a phone, and a popover anchored to the trigger on wide
/// layouts and under a pointer. Under touch the search waits for a tap, so the
/// keyboard stays down until the user wants it.
///
/// The search sits first, and the list holds only folder projects. Buttons
/// pinned below the list, which the search leaves alone, are there with one
/// project, with none, and when nothing matches. "No project" leads them on a
/// bridge that has it, and picks it like a project. Choosing a new session's
/// project, it sits beside "Open folder…", which opens the folder browser and
/// then selects the project that adds. Filtering a list instead
/// ([onAllProjects] set), it sits beside "All projects", checked while no
/// project is chosen. A path shows only under a name another project shares.
class const ProjectPicker({
  super.key,

  /// Null selects nothing, or every project while filtering.
  required final String? selectedProjectId,
  required final NewSessionProjectSelected onSelected,

  /// Clears a list's filter. Set, the picker filters: "All projects" is
  /// pinned below the list in place of "Open folder…".
  required final VoidCallback? onAllProjects,

  /// Builds the trigger; the callback opens the picker.
  required final PregoPopoverTriggerBuilder triggerBuilder,
}) extends StatelessWidget {
  static const double _popoverWidth = 320;

  @override
  Widget build(BuildContext context) {
    // The sheet and the popover are routes of their own, outside this
    // subtree's providers, and the list they show stays live.
    final cubit = context.read<ProjectListCubit>();
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    Widget list({required VoidCallback close}) => BlocProvider.value(
      value: cubit,
      child: _ProjectPickerList(
        selectedProjectId: selectedProjectId,
        onSelected: onSelected,
        onAllProjects: onAllProjects,
        // Runs once the picker's route has finished closing. The folder
        // browser opens over this widget's context, which outlives the picker.
        onOpenFolder: () => unawaited(
          showAddProjectDialog(
            context: context,
            onProjectAdded: ({required context, required project, required displayName}) =>
                onSelected(projectId: project.id, projectName: displayName),
          ),
        ),
        onClose: close,
      ),
    );
    if (pointer || MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint) {
      return PregoPopover(
        popoverWidth: _popoverWidth,
        popoverMaxHeight: PregoPickerPopover.maxHeight,
        contentScrolls: true,
        popoverBorderRadius: pointer ? PregoRadius.md : PregoRadius.x4l,
        onClosed: null,
        triggerBuilder: triggerBuilder,
        contentBuilder: (_, close) => list(close: close),
      );
    }
    return triggerBuilder(
      context,
      () => unawaited(
        showPregoBottomSheet<void>(
          context: context,
          title: context.loc.projectPickerTitle,
          contentPadding: EdgeInsetsDirectional.zero,
          // A fixed height keeps the search field still while matches narrow.
          bodySize: PregoBottomSheetBodySize.seventyPercent,
          builder: (sheetContext) => list(
            // ignore: no_slop_linter/avoid_navigator_of, pops the pageless sheet route this picker pushed
            close: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
    );
  }
}

class const _ProjectPickerList({
  required final String? selectedProjectId,
  required final NewSessionProjectSelected onSelected,
  required final VoidCallback? onAllProjects,
  required final VoidCallback onOpenFolder,
  required final VoidCallback onClose,
}) extends StatefulWidget {
  @override
  State<_ProjectPickerList> createState() => _ProjectPickerListState();
}

class _ProjectPickerListState() extends State<_ProjectPickerList> {
  String _query = "";
  List<ProjectSummary> _projects = const [];

  /// Kept until the query or the list changes, so other rebuilds keep the
  /// highlight.
  List<PregoPickerSearchRow>? _rows;

  void _pickProject({required ProjectSummary project, required String name}) {
    widget.onClose();
    if (project.id != widget.selectedProjectId) widget.onSelected(projectId: project.id, projectName: name);
  }

  List<PregoPickerSearchRow> _buildRows() {
    final loc = context.loc;
    final query = _query;
    final projects = _projects;
    String nameOf(ProjectSummary project) => projectDisplayName(loc: loc, project: project);
    final nameCounts = <String, int>{};
    for (final project in projects) {
      nameCounts.update(nameOf(project), (count) => count + 1, ifAbsent: () => 1);
    }
    final pathLabels = projectPathLabels(projects: projects, nameOf: nameOf);
    final matches = [
      for (final project in projects)
        if (query.isEmpty ||
            nameOf(project).toLowerCase().contains(query) ||
            project.path.toLowerCase().contains(query))
          project,
    ];
    return [
      if (matches.isEmpty && query.isNotEmpty) PregoPickerSearchNote(text: loc.projectPickerNoMatches),
      for (final project in matches)
        PregoPickerSearchOption(
          isSelected: project.id == widget.selectedProjectId,
          onPick: () => _pickProject(project: project, name: nameOf(project)),
          child: _PickerRow(
            title: nameOf(project),
            // Only a shared name needs its path to be told apart.
            detail: (nameCounts[nameOf(project)] ?? 0) > 1 ? pathLabels[project.id] ?? project.path : null,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final (projects, scratchProject) = context.select(
      (ProjectListCubit cubit) => switch (cubit.state) {
        ProjectListLoaded(:final folderProjects, :final scratchProject) => (folderProjects, scratchProject),
        ProjectListLoading() ||
        ProjectListFailed() ||
        ProjectListBridgeDisconnected() => (const <ProjectSummary>[], null),
      },
    );
    var rows = _rows;
    if (rows == null || !identical(projects, _projects)) {
      _projects = projects;
      rows = _rows = _buildRows();
    }
    final trailing = switch (widget.onAllProjects) {
      null => PregoPickerSearchFooterAction(
        label: loc.projectPickerOpenFolder,
        icon: TablerRegular.folder_plus,
        isSelected: false,
        onPick: () {
          final route = ModalRoute.of(context);
          widget.onClose();
          // A popped route completes only once its closing animation ends.
          unawaited(route?.completed.then((_) => widget.onOpenFolder()));
        },
      ),
      // Checked when it is already the choice, so it never reads as one
      // more project.
      final onAllProjects => PregoPickerSearchFooterAction(
        label: loc.projectPickerAllProjects,
        icon: TablerRegular.folders,
        isSelected: widget.selectedProjectId == null,
        onPick: () {
          widget.onClose();
          if (widget.selectedProjectId != null) onAllProjects();
        },
      ),
    };
    return PregoPickerSearchList(
      searchHint: loc.projectPickerSearchHint,
      onQueryChanged: (query) => setState(() {
        _query = query;
        _rows = _buildRows();
      }),
      // Actions rather than projects, so the search leaves them alone.
      footer: switch (scratchProject) {
        null => PregoPickerSearchFooter.single(action: trailing),
        final scratchProject => PregoPickerSearchFooter.pair(
          leading: PregoPickerSearchFooterAction(
            label: loc.projectPickerNoProject,
            icon: TablerRegular.folder_off,
            isSelected: scratchProject.id == widget.selectedProjectId,
            onPick: () => _pickProject(project: scratchProject, name: loc.projectPickerNoProject),
          ),
          trailing: trailing,
        ),
      },
      rows: rows,
      emptyText: null,
      onClose: widget.onClose,
    );
  }
}

/// A project's folder icon and name, over the path that tells it apart when it
/// has one.
class const _PickerRow({required final String title, required final String? detail}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final detail = this.detail;
    return Row(
      spacing: PregoSpacing.md,
      children: [
        Icon(TablerRegular.folder, size: PregoIconSize.sm, color: prego.colors.textTertiary),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary),
              ),
              if (detail != null)
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
