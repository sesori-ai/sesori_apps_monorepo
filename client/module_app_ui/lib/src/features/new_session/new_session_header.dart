import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../project_list/project_path_labels.dart";
import "../project_picker/project_picker.dart";
import "../session_detail/widgets/transcript_motion.dart";

/// [projectId]'s name in the live project list, which knows a rename the
/// route's [projectName] can miss.
String liveProjectName({required BuildContext context, required String projectId, required String? projectName}) {
  final loc = context.loc;
  final current = context.select(
    (ProjectListCubit cubit) => switch (cubit.state) {
      ProjectListLoaded(:final projects) => projects.where((project) => project.id == projectId).firstOrNull,
      ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => null,
    },
  );
  return current == null ? projectName ?? loc.projectListDefaultName : projectDisplayName(loc: loc, project: current);
}

/// The new session page's opening: what the page is for, and which project the
/// session starts in. With [onProjectSelected] the project opens the picker;
/// without it the header only names the project.
class const NewSessionHeader({
  super.key,
  required final String projectId,
  required final String? projectName,
  required final NewSessionProjectSelected? onProjectSelected,
  required final Widget? harness,
}) extends StatefulWidget {
  @override
  State<NewSessionHeader> createState() => _NewSessionHeaderState();
}

class _NewSessionHeaderState() extends State<NewSessionHeader> with SingleTickerProviderStateMixin {
  /// The harness's room beside the project, from gone (0) to held (1).
  late final AnimationController _harnessMotion;

  @override
  void initState() {
    super.initState();
    _harnessMotion = AnimationController(
      vsync: this,
      duration: transcriptMotionDuration,
      value: widget.harness == null ? 0 : 1,
    );
  }

  @override
  void didUpdateWidget(NewSessionHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final held = widget.harness != null;
    if (held == (oldWidget.harness != null)) return;
    if (context.isReducedMotion) {
      _harnessMotion.value = held ? 1 : 0;
    } else if (held) {
      _harnessMotion.forward();
    } else {
      _harnessMotion.reverse();
    }
  }

  @override
  void dispose() {
    _harnessMotion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final NewSessionHeader(:projectId, :projectName, :onProjectSelected, :harness) = widget;
    final label = onProjectSelected == null
        ? projectName ?? loc.projectListDefaultName
        : liveProjectName(context: context, projectId: projectId, projectName: projectName);
    Widget pill({required VoidCallback? onPressed}) => PregoButtonsSolid(
      key: const Key("new_session_project"),
      label: label,
      leadingIcon: TablerRegular.folder,
      trailingIcon: onPressed == null ? null : TablerRegular.chevron_down,
      hierarchy: PregoButtonsSolidHierarchy.secondary,
      size: PregoButtonsSolidSize.sm,
      onPressed: onPressed,
    );
    return Column(
      spacing: PregoSpacing.lg,
      children: [
        Text(
          loc.newSessionHeading,
          textAlign: TextAlign.center,
          style: prego.textTheme.displayXs.bold.copyWith(color: prego.colors.textPrimary),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: PregoSpacing.md,
          runSpacing: PregoSpacing.md,
          children: [
            // The harness's room leaves at once when discovery fails or finds
            // none, and returns at once when it runs again, so the project
            // paints from where it was and slides to its new place. Across
            // only: the column moving around the header carries it with the
            // heading.
            PregoSlideFromLastPosition(
              progress: _harnessMotion,
              forward: harness != null,
              horizontalOnly: true,
              child: onProjectSelected == null
                  ? pill(onPressed: null)
                  : ProjectPicker(
                      selectedProjectId: projectId,
                      onSelected: onProjectSelected,
                      onAllProjects: null,
                      triggerBuilder: (_, open) => pill(onPressed: open),
                    ),
            ),
            // The harness's width eases as its shimmer turns into the
            // chooser, so the centred row glides rather than jumps. Under
            // reduced motion no wrapper at all: a zero-length AnimatedSize
            // would re-dirty itself mid-layout.
            if (harness case final harness?)
              context.isReducedMotion
                  ? harness
                  : AnimatedSize(duration: transcriptMotionDuration, curve: transcriptMotionCurve, child: harness),
          ],
        ),
      ],
    );
  }
}
