import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Builds a surface that draws launching rows per project, with each
/// project's [LaunchRows] from the surface's own [ProjectLaunchRowsCubit].
class const ProjectLaunchRowsBuilder({
  super.key,

  /// See [ProjectLaunchRowsCubit.new]; read once, when the surface opens.
  required final Map<String, LaunchRows> initialRows,
  required final Widget Function({required BuildContext context, required Map<String, LaunchRows> launchRows}) builder,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => ProjectLaunchRowsCubit(
      window: context.read<SessionWindowService>(),
      launchService: context.read<SessionLaunchService>(),
      initialRows: initialRows,
    ),
    child: BlocBuilder<ProjectLaunchRowsCubit, Map<String, LaunchRows>>(
      builder: (context, launchRows) => builder(context: context, launchRows: launchRows),
    ),
  );
}
