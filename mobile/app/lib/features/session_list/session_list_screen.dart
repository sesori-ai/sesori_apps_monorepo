import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../core/constants.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/app_modal_bottom_sheet.dart";
import "../../l10n/app_localizations.dart";
import "rename_session_dialog.dart";
import "session_list_cubit_provider.dart";
import "session_list_scaffold.dart";

part "session_list_actions.dart";
part "session_list_action_dispatcher.dart";
part "session_cleanup_dialogs.dart";
part "session_force_dialog.dart";

class SessionListScreen extends StatelessWidget {
  final String projectId;
  final String? projectName;

  const SessionListScreen({
    super.key,
    required this.projectId,
    this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return SessionListCubitProvider(
      projectId: projectId,
      child: _SessionListBody(
        projectId: projectId,
        projectName: projectName,
      ),
    );
  }
}

class _SessionListBody extends StatelessWidget {
  final String projectId;
  final String? projectName;

  const _SessionListBody({required this.projectId, this.projectName});

  @override
  Widget build(BuildContext context) {
    const actionDispatcher = SessionListActionDispatcher();

    return SessionListScaffold(
      projectName: projectName,
      onNewSession: () {
        context.pushRoute(AppRoute.newSession(projectId: projectId));
      },
      onSessionTap: (session) {
        context.pushRoute(
          AppRoute.sessionDetail(
            projectId: projectId,
            sessionId: session.id,
            sessionTitle: session.title ?? "",
            readOnly: false,
          ),
        );
      },
      onSessionLongPress: (session) => actionDispatcher.showSessionActions(context: context, session: session),
      onSessionSwipe: (session) => actionDispatcher.handleSessionSwipe(context: context, session: session),
    );
  }
}
