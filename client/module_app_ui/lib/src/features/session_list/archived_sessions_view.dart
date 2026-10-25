import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "all_sessions_list.dart";
import "session_list_action_dispatcher.dart";

/// Archived sessions across projects, from an archived-mode
/// [AllSessionsCubit]. The product shell owns its provider, assets and routes.
class const ArchivedSessionsView({
  super.key,
  required final Widget emptyState,
  required final AllSessionsDisconnectedBuilder disconnectedBuilder,
  required final VoidCallback onClose,
  required final AllSessionsRowOpenedCallback onSessionTap,
  required final SessionListActionDispatcher actionDispatcher,
  required final ActionSessionListCubitFactory createActionCubit,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PregoGlassScaffold(
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
    onRefresh: () => _refresh(context: context),
    slivers: [
      AllSessionsList(
        onSessionTap: onSessionTap,
        actionDispatcher: actionDispatcher,
        createActionCubit: createActionCubit,
        selectedSessionId: null,
        disconnectedBuilder: disconnectedBuilder,
        emptyState: emptyState,
      ),
    ],
  );

  static Future<void> _refresh({required BuildContext context}) async {
    final loc = context.loc;
    final success = await context.read<SessionListRefreshCubit>().refresh();
    if (!context.mounted) return;
    PregoPopupAlertPresenter.of(context).show(
      title: success ? loc.sessionListRefreshSuccess : loc.sessionListRefreshFailed,
      variant: success ? PregoPopupAlertsNotificationsVariant.success : PregoPopupAlertsNotificationsVariant.error,
    );
  }
}
