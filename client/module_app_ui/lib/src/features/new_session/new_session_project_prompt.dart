import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../project_list/add_project_dialog.dart";
import "../project_picker/project_picker.dart";

/// The new-session page, or the home's composer pane, before it has a project:
/// it asks for one, with nothing selected. With no projects at all the picker
/// offers only "Open folder…", or [offersFirstRunStep] replaces it.
class const NewSessionProjectPrompt({
  super.key,
  required final NewSessionProjectSelected onProjectSelected,

  /// Null where nothing lies behind the page, such as the home's content pane.
  required final VoidCallback? onBack,
  required final Widget? banner,

  /// Opens the picker once the page is up, for a page just asked for. A pane
  /// at rest waits for a tap instead.
  required final bool opensPicker,

  /// With no projects at all, shows adding a folder as the one next step in
  /// place of the picker.
  required final bool offersFirstRunStep,

  /// A pointer surface's bar in place of the glass one; the prompt then sits
  /// in the centred column the composer page uses, over its pane's background
  /// as it paints none. Null keeps the glass bar.
  required final Widget? topBar,
}) extends StatefulWidget {
  @override
  State<NewSessionProjectPrompt> createState() => _NewSessionProjectPromptState();
}

class _NewSessionProjectPromptState() extends State<NewSessionProjectPrompt> {
  VoidCallback? _openPicker;

  @override
  void initState() {
    super.initState();
    if (!widget.opensPicker) return;
    // The picker's trigger exists only after the first frame, and the picker
    // rises once the page has settled, never over it still moving in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final entrance = ModalRoute.of(context)?.animation;
      if (entrance == null || entrance.isCompleted) return _openPicker?.call();
      late final AnimationStatusListener settled;
      settled = (status) {
        if (status.isAnimating) return;
        entrance.removeStatusListener(settled);
        if (mounted && status.isCompleted) _openPicker?.call();
      };
      entrance.addStatusListener(settled);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final firstRun =
        widget.offersFirstRunStep &&
        switch (context.select((ProjectListCubit cubit) => cubit.state)) {
          ProjectListLoaded(:final projects) => projects.isEmpty,
          ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => false,
        };
    final prompt = firstRun
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loc.newSessionNoProjectsHeading,
                textAlign: TextAlign.center,
                style: prego.textTheme.displayXs.bold.copyWith(color: prego.colors.textPrimary),
              ),
              const SizedBox(height: PregoSpacing.xs),
              Text(
                loc.newSessionNoProjectsHint,
                textAlign: TextAlign.center,
                style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
              ),
              const SizedBox(height: PregoSpacing.xl),
              PregoButtonsSolid(
                key: const Key("new_session_add_first_project"),
                label: loc.addProject,
                leadingIcon: TablerRegular.folder_plus,
                hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                size: PregoButtonsSolidSize.md,
                onPressed: () => unawaited(
                  showAddProjectDialog(
                    context: context,
                    onProjectAdded: ({required context, required project, required displayName}) =>
                        widget.onProjectSelected(projectId: project.id, projectName: displayName),
                  ),
                ),
              ),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            spacing: PregoSpacing.lg,
            children: [
              Text(
                loc.newSessionHeading,
                textAlign: TextAlign.center,
                style: prego.textTheme.displayXs.bold.copyWith(color: prego.colors.textPrimary),
              ),
              ProjectPicker(
                selectedProjectId: null,
                onSelected: widget.onProjectSelected,
                onAllProjects: null,
                triggerBuilder: (_, open) {
                  _openPicker = open;
                  return PregoButtonsSolid(
                    key: const Key("new_session_project"),
                    label: loc.projectPickerChooseProject,
                    leadingIcon: TablerRegular.folder,
                    trailingIcon: TablerRegular.chevron_down,
                    hierarchy: PregoButtonsSolidHierarchy.secondary,
                    size: PregoButtonsSolidSize.sm,
                    onPressed: open,
                  );
                },
              ),
            ],
          );
    if (widget.topBar case final topBar?) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        // A short window scrolls the bar and the prompt together.
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [?widget.banner, topBar],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(padding: const EdgeInsets.all(PregoSpacing.xl), child: prompt),
              ),
            ),
          ],
        ),
      );
    }
    return PregoGlassScaffold(
      title: loc.sessionListNewSession,
      onBack: widget.onBack,
      titleMode: PregoTopNavigationTitleMode.backLeading,
      subtitle: null,
      banner: widget.banner,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(PregoSpacing.xl),
          sliver: SliverToBoxAdapter(child: prompt),
        ),
      ],
    );
  }
}
