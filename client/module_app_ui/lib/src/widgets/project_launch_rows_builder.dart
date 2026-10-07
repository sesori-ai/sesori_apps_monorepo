import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

/// A home's Activity slots: each project's running rows, which its launching
/// rows lead.
Map<String, List<Session>> runningActivitySlots({required SessionActivityProjection projection}) {
  final slots = <String, List<Session>>{};
  for (final (:project, :entry) in projection.running) {
    (slots[project.id] ??= []).add(entry.session);
  }
  return slots;
}

/// Builds a surface that draws launching rows per project, with each
/// project's [LaunchRows] from the surface's own [ProjectLaunchRowsCubit].
class const ProjectLaunchRowsBuilder({
  super.key,

  /// See [ProjectLaunchRowsCubit.new]; read once, when the surface opens.
  required final Map<String, LaunchRows> initialRows,
  required final ProjectLaunchSlots slots,
  required final Widget Function({required BuildContext context, required Map<String, LaunchRows> launchRows}) builder,
}) extends StatefulWidget {
  @override
  State<ProjectLaunchRowsBuilder> createState() => _ProjectLaunchRowsBuilderState();
}

// Stateful only so the cubit reads [slots] through the current widget.
class _ProjectLaunchRowsBuilderState() extends State<ProjectLaunchRowsBuilder> {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => ProjectLaunchRowsCubit(
      inventoryService: context.read<RecentSessionInventoryService>(),
      launchService: context.read<SessionLaunchService>(),
      slots: ({required entries}) => widget.slots(entries: entries),
      initialRows: widget.initialRows,
    ),
    child: BlocBuilder<ProjectLaunchRowsCubit, Map<String, LaunchRows>>(
      builder: (context, launchRows) => widget.builder(context: context, launchRows: launchRows),
    ),
  );
}
