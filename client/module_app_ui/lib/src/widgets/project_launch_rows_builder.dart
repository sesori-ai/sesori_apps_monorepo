import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Each project's sessions in the slot its launching rows lead.
typedef ProjectLaunchSlots = Map<String, List<Session>> Function({required Map<String, RecentSessionsEntry> entries});

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
/// project's [LaunchRows] (see [resolveProjectLaunchRows]).
///
/// The rows are resolved on every inventory and launch update rather than in
/// build, so each update is seen once and a launch's session is never missed.
class const ProjectLaunchRowsBuilder({
  super.key,

  /// The rows to continue from. A surface opened from another that already
  /// draws these launches passes that one's rows, so it keeps the launching
  /// rows that one still holds after their launches have left the cubit.
  required final Map<String, LaunchRows> initialRows,
  required final ProjectLaunchSlots slots,
  required final Widget Function({required BuildContext context, required Map<String, LaunchRows> launchRows}) builder,
}) extends StatefulWidget {
  @override
  State<ProjectLaunchRowsBuilder> createState() => _ProjectLaunchRowsBuilderState();
}

class _ProjectLaunchRowsBuilderState() extends State<ProjectLaunchRowsBuilder> {
  late final StreamSubscription<Map<String, RecentSessionsEntry>> _entries;
  late final StreamSubscription<SessionLaunchState> _launches;
  late Map<String, LaunchRows> _rows = widget.initialRows;

  @override
  void initState() {
    super.initState();
    _rows = _resolve();
    _entries = context.read<RecentSessionsCubit>().stream.listen((_) => setState(() => _rows = _resolve()));
    _launches = context.read<SessionLaunchCubit>().stream.listen((_) => setState(() => _rows = _resolve()));
  }

  @override
  void dispose() {
    unawaited(_entries.cancel());
    unawaited(_launches.cancel());
    super.dispose();
  }

  Map<String, LaunchRows> _resolve() {
    final entries = context.read<RecentSessionsCubit>().state;
    return resolveProjectLaunchRows(
      previous: _rows,
      launches: context.read<SessionLaunchCubit>().state,
      entries: entries,
      slots: widget.slots(entries: entries),
    );
  }

  @override
  Widget build(BuildContext context) => widget.builder(context: context, launchRows: _rows);
}
