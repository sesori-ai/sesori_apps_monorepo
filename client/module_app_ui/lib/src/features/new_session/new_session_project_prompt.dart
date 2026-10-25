import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../project_picker/project_picker.dart";

/// The new-session page, or the home's composer pane, before it has a project:
/// it asks for one, with nothing selected. With no projects at all the picker
/// offers only "Open another folder…".
class const NewSessionProjectPrompt({
  super.key,
  required final NewSessionProjectSelected onProjectSelected,

  /// Null where nothing lies behind the page, such as the home's content pane.
  required final VoidCallback? onBack,
  required final Widget? banner,

  /// Opens the picker once the page is up, for a page just asked for. A pane
  /// at rest waits for a tap instead.
  required final bool opensPicker,
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
    // The picker's trigger exists only after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openPicker?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    return PregoGlassScaffold(
      title: loc.sessionListNewSession,
      onBack: widget.onBack,
      titleMode: PregoTopNavigationTitleMode.backLeading,
      subtitle: null,
      banner: widget.banner,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(PregoSpacing.xl),
          sliver: SliverToBoxAdapter(
            child: Column(
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
            ),
          ),
        ),
      ],
    );
  }
}
