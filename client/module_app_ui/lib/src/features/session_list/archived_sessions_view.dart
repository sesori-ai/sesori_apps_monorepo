import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "session_list_action_dispatcher.dart";
import "session_list_content.dart";
import "session_tile.dart";

/// Archive presentation. The product shell owns its provider, assets and routes.
class const ArchivedSessionsView({
  super.key,
  required final Widget emptyState,
  required final VoidCallback onClose,
  required final SessionOpenedCallback onSessionTap,
  required final SessionListActionDispatcher actionDispatcher,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionListCubit>().state;
    return PregoGlassScaffold(
      title: context.loc.archivedSessionsTitle,
      titleMode: PregoTopNavigationTitleMode.inline,
      onBack: null,
      automaticallyImplyLeading: false,
      actions: [
        PregoButtonsIconGlass(
          icon: TablerRegular.x,
          semanticLabel: context.loc.archivedSessionsClose,
          onPressed: onClose,
        ),
      ],
      onRefresh: state is SessionListLoaded ? () => refreshSessionList(context) : null,
      slivers: [
        if (state is SessionListLoaded && state.isRefreshing)
          const SliverToBoxAdapter(child: LinearProgressIndicator()),
        SessionListContent(
          projectName: null,
          onSessionTap: onSessionTap,
          actionDispatcher: actionDispatcher,
          archivedEmptyState: emptyState,
        ),
      ],
    );
  }
}
