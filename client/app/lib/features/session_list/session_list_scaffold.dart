import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";
import "../../core/widgets/connection_banner.dart";
import "../../core/widgets/project_nav_subtitle.dart";
import "session_list_content.dart";
import "session_tile.dart";

class const SessionListScaffold({
  super.key,
  final String? projectName,
  final String? selectedSessionId,
  required final ValueChanged<Session> onSessionTap,
  required final SessionMenuEntriesBuilder sessionMenuEntries,
  required final VoidCallback onNewSession,
  required final VoidCallback? onBack,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionListCubit>().state;
    final showArchived = state is SessionListLoaded && state.showArchived;
    final isRefreshing = state is SessionListLoaded && state.isRefreshing;

    return PregoGlassScaffold(
      // The sessions route sits at the base of the nested pane navigator, so
      // the bar cannot imply a back button — the poppable route lives on the
      // root navigator. Render it explicitly from the injected callback.
      onBack: onBack,
      // The bar's back-leading block identifies context: the project name over
      // the repository slug of its git remote.
      title: projectName ?? loc.sessionListTitle,
      titleMode: PregoTopNavigationTitleMode.backLeading,
      subtitle: buildProjectNavSubtitle(context),
      banner: ConnectionBanner.maybeFor(context),
      actions: [
        PregoButtonsIconGlass(
          icon: TablerRegular.archive,
          // Tint when the archived filter is active (Tabler has no filled
          // variant), replacing the old filled/outlined Material toggle.
          iconColor: showArchived ? context.prego.colors.bgBrandSolid : null,
          semanticLabel: loc.sessionListToggleArchived,
          onPressed: () {
            final cubit = context.read<SessionListCubit>();
            if (cubit.state is SessionListLoaded) {
              cubit.toggleArchived();
            }
          },
        ),
      ],
      floatingActionButton: PregoButtonsSolid(
        label: loc.sessionListNewTask,
        leadingIcon: TablerRegular.plus,
        hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
        size: PregoButtonsSolidSize.xl,
        onPressed: onNewSession,
      ),
      // Pull-to-refresh only makes sense once the list has loaded.
      onRefresh: state is SessionListLoaded ? () => refreshSessionList(context) : null,
      slivers: [
        if (isRefreshing) const SliverToBoxAdapter(child: LinearProgressIndicator()),
        SessionListContent(
          projectName: projectName,
          selectedSessionId: selectedSessionId,
          onSessionTap: onSessionTap,
          sessionMenuEntries: sessionMenuEntries,
        ),
      ],
    );
  }
}
