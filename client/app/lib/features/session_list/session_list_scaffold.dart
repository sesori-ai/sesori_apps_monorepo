import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";
import "../../core/widgets/connection_banner.dart";
import "../../l10n/app_localizations.dart";
import "session_list_content.dart";
import "session_tile.dart";

class SessionListScaffold extends StatelessWidget {
  final String? projectName;
  final String? selectedSessionId;
  final ValueChanged<Session> onSessionTap;
  final SessionMenuEntriesBuilder sessionMenuEntries;
  final ValueChanged<Session> onSessionSwipe;
  final VoidCallback onNewSession;
  final VoidCallback? onBack;

  const SessionListScaffold({
    super.key,
    this.projectName,
    this.selectedSessionId,
    required this.onSessionTap,
    required this.sessionMenuEntries,
    required this.onSessionSwipe,
    required this.onNewSession,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionListCubit>().state;
    final showArchived = state is SessionListLoaded && state.showArchived;
    final baseBranch = state is SessionListLoaded ? state.baseBranch : null;
    final isRefreshing = state is SessionListLoaded && state.isRefreshing;

    return PregoGlassScaffold(
      // The sessions route sits at the base of the nested pane navigator, so
      // the bar cannot imply a back button — the poppable route lives on the
      // root navigator. Render it explicitly from the injected callback.
      onBack: onBack,
      title: _title(loc: loc),
      subtitle: baseBranch,
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
          onSessionSwipe: onSessionSwipe,
        ),
      ],
    );
  }

  String _title({required AppLocalizations loc}) => switch (projectName) {
    final name? => loc.sessionListTitleWithName(name),
    null => loc.sessionListTitle,
  };
}
