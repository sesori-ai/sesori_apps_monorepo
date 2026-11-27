import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart" show ProjectKind, ProjectSummary, sessionForkTitleSuffix;
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/session_sidebar/session_sidebar_shell.dart";
import "../project_list/project_path_labels.dart";

typedef SessionPickerSelected = void Function({required SessionSearchMatch target});

/// Chooses a session of any project from the [SessionSearchCubit] above it,
/// searchable by title: a bottom sheet over the caller's sheet on a phone, and
/// a popover anchored to the trigger on wide layouts and under a pointer. The
/// blank search lists the newest sessions. A running row says what sending
/// does to it.
class const SessionPicker({
  super.key,
  required final String? selectedSessionId,
  required final SessionPickerSelected onSelected,

  /// Builds the trigger; the callback opens the picker.
  required final PregoPopoverTriggerBuilder triggerBuilder,
}) extends StatelessWidget {
  static const double _popoverWidth = 360;

  @override
  Widget build(BuildContext context) {
    // The sheet and the popover are routes of their own, outside this
    // subtree's providers, and the list they show stays live.
    final cubit = context.read<SessionSearchCubit>();
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: presenter
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    Widget list({required VoidCallback close}) => BlocProvider.value(
      value: cubit,
      child: _SessionPickerList(selectedSessionId: selectedSessionId, onSelected: onSelected, onClose: close),
    );
    // Each opening starts from a blank search, as its field does.
    void clearSearch() => cubit.setQuery(query: "");
    if (pointer || MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint) {
      return PregoPopover(
        popoverWidth: _popoverWidth,
        popoverMaxHeight: PregoPickerPopover.maxHeight,
        contentScrolls: true,
        popoverBorderRadius: pointer ? PregoRadius.xl : PregoRadius.x4l,
        placement: pointer ? AnchoredPanelPlacement.atCorner : AnchoredPanelPlacement.besideTrigger,
        onClosed: null,
        triggerBuilder: (context, toggle) => triggerBuilder(context, () {
          clearSearch();
          toggle();
        }),
        contentBuilder: (_, close) => list(close: close),
      );
    }
    return triggerBuilder(context, () {
      clearSearch();
      unawaited(
        showPregoBottomSheet<void>(
          context: context,
          title: context.loc.sessionPickerTitle,
          contentPadding: EdgeInsetsDirectional.zero,
          // A fixed height keeps the search field still while matches narrow.
          bodySize: PregoBottomSheetBodySize.seventyPercent,
          builder: (sheetContext) => list(
            // ignore: no_slop_linter/avoid_navigator_of, pops the pageless sheet route this picker pushed
            close: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      );
    });
  }
}

class const _SessionPickerList({
  required final String? selectedSessionId,
  required final SessionPickerSelected onSelected,
  required final VoidCallback onClose,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionSearchCubit>().state;
    final searching = state.isSearching && state.matches.isEmpty;
    String nameOf(ProjectSummary project) => projectDisplayName(loc: loc, project: project);
    final projects = {
      for (final match in state.matches)
        if (match.project.kind != ProjectKind.scratch) match.project.id: match.project,
    }.values.toList();
    final nameCounts = <String, int>{};
    for (final project in projects) {
      nameCounts.update(nameOf(project), (count) => count + 1, ifAbsent: () => 1);
    }
    final pathLabels = projectPathLabels(projects: projects, nameOf: nameOf);
    // Only a shared name needs its path to be told apart. A session without
    // a project names none.
    String? projectLabel(ProjectSummary project) => switch (project.kind) {
      ProjectKind.scratch => null,
      _ => (nameCounts[nameOf(project)] ?? 0) > 1 ? pathLabels[project.id] ?? project.path : nameOf(project),
    };
    return PregoPickerSearchList(
      searchHint: loc.sessionPickerSearchHint,
      onQueryChanged: (query) => context.read<SessionSearchCubit>().setQuery(query: query),
      footer: null,
      rows: searching
          ? null
          : [
              for (final match in state.matches)
                PregoPickerSearchOption(
                  isSelected: match.session.id == selectedSessionId,
                  onPick: () {
                    onClose();
                    onSelected(target: match);
                  },
                  child: _SessionPickerRow(match: match, projectLabel: projectLabel(match.project)),
                ),
            ],
      emptyText: searching ? null : loc.sessionPickerNoMatches,
      onClose: onClose,
    );
  }
}

/// A session's title, over its project ([projectLabel], null for a session
/// without one) and, while it runs, what sending does to it. A row with nothing
/// under its title keeps a two-line row's height, its title centred, so the
/// rows stay even.
class const _SessionPickerRow({required final SessionSearchMatch match, required final String? projectLabel})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final details = [
      ?projectLabel,
      ?switch (match.running) {
        null => null,
        RunningTarget.stopsTurn => loc.sessionPickerRunningStopsTurn,
        RunningTarget.keepsTurn => loc.sessionPickerRunning,
      },
    ];
    final titleStyle = prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary);
    final detailsStyle = prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: context.lineHeightOf(titleStyle) + context.lineHeightOf(detailsStyle)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PregoKeptSuffixText(
            text: match.session.title ?? loc.sessionListUntitled,
            keptSuffix: sessionForkTitleSuffix,
            style: titleStyle,
          ),
          if (details.isNotEmpty)
            Text(details.join(" · "), maxLines: 1, overflow: TextOverflow.ellipsis, style: detailsStyle),
        ],
      ),
    );
  }
}
