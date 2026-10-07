import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

/// What an Activity surface's slots read besides the inventory: the inputs of
/// its [SessionActivityProjection].
typedef ActivitySlotInputs = ({
  List<ProjectSummary> projects,
  Map<String, int> deferredSessions,
  Set<String> hiddenSessionIds,
  String? stickySessionId,
});

/// The Activity an Activity surface lists, from the inventory and its inputs.
SessionActivityProjection activityProjection({
  required Map<String, RecentSessionsEntry> entries,
  required ActivitySlotInputs inputs,
}) => SessionActivityProjection.from(
  projects: inputs.projects,
  entries: entries,
  deferredSessions: inputs.deferredSessions,
  stickySessionId: inputs.stickySessionId,
  hiddenSessionIds: inputs.hiddenSessionIds,
);

/// A home's Activity slots: each project's running rows, which its launching
/// rows lead. A launch whose session waits on the user gives way to it in
/// Needs you.
Map<String, LaunchSlot> runningActivitySlots({
  required Map<String, RecentSessionsEntry> entries,
  required ActivitySlotInputs inputs,
}) {
  final projection = activityProjection(entries: entries, inputs: inputs);
  final running = <String, List<Session>>{};
  for (final (:project, :entry) in projection.running) {
    (running[project.id] ??= []).add(entry.session);
  }
  final needsYou = <String, Set<String>>{};
  for (final (:project, :entry) in projection.needsYou) {
    (needsYou[project.id] ??= {}).add(entry.session.id);
  }
  return {
    for (final projectId in {...running.keys, ...needsYou.keys})
      projectId: (sessions: running[projectId] ?? const [], placedSessionIds: needsYou[projectId] ?? const {}),
  };
}

/// Builds a surface that draws launching rows per project, with each
/// project's [LaunchRows] from the surface's own [ProjectLaunchRowsCubit].
class const ProjectLaunchRowsBuilder<T>({
  super.key,

  /// See [ProjectLaunchRowsCubit.new]; read once, when the surface opens.
  required final Map<String, LaunchRows> initialRows,

  /// Read once, when the surface opens; see [ProjectLaunchSlots].
  required final ProjectLaunchSlots<T> slots,

  /// The slots' current inputs; a change re-resolves the rows.
  required final T slotInputs,
  required final Widget Function({required BuildContext context, required Map<String, LaunchRows> launchRows}) builder,
}) extends StatefulWidget {
  @override
  State<ProjectLaunchRowsBuilder<T>> createState() => _ProjectLaunchRowsBuilderState<T>();
}

class _ProjectLaunchRowsBuilderState<T>() extends State<ProjectLaunchRowsBuilder<T>> {
  // The cubit the provider below created, kept to pass it the slots' inputs.
  ProjectLaunchRowsCubit<T>? _cubit;

  @override
  void didUpdateWidget(ProjectLaunchRowsBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cubit?.updateSlotInputs(inputs: widget.slotInputs);
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => _cubit = ProjectLaunchRowsCubit<T>(
      inventoryService: context.read<RecentSessionInventoryService>(),
      launchService: context.read<SessionLaunchService>(),
      slots: widget.slots,
      slotInputs: widget.slotInputs,
      initialRows: widget.initialRows,
    ),
    child: BlocBuilder<ProjectLaunchRowsCubit<T>, Map<String, LaunchRows>>(
      builder: (context, launchRows) => widget.builder(context: context, launchRows: launchRows),
    ),
  );
}
