import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/constants.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../l10n/app_localizations.dart";
import "rename_session_dialog.dart";
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
    return _SessionListBody(
      projectId: projectId,
      projectName: projectName,
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
    // The sessions route is the base of the nested pane navigator, so the
    // pane navigator can never pop it; the poppable session shell route (with
    // /projects underneath) lives on the root navigator.
    // ignore: no_slop_linter/avoid_navigator_of, root navigator pop is required so back exits the session shell to the projects list instead of targeting the nested pane navigator
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    return SessionListScaffold(
      projectName: projectName,
      // ignore: unnecessary_lambdas, Navigator.pop is generic and does not match VoidCallback as a tear-off
      onBack: rootNavigator.canPop() ? () => rootNavigator.pop() : null,
      onNewSession: () {
        context.pushRoute(AppRoute.newSession(projectId: projectId, projectName: projectName));
      },
      onSessionTap: (session) {
        context.goRoute(
          AppRoute.sessionDetail(
            projectId: projectId,
            projectName: projectName,
            sessionId: session.id,
            sessionTitle: session.title ?? "",
            readOnly: false,
          ),
        );
      },
      sessionMenuEntries: (BuildContext context, Session session) =>
          actionDispatcher.sessionMenuEntries(context: context, session: session),
      onSessionArchive: (session) => actionDispatcher.handleSessionArchive(context: context, session: session),
      onSessionDelete: (session) => actionDispatcher.handleSessionDelete(context: context, session: session),
      onSessionToggleUnread: (session) =>
          actionDispatcher.handleSessionToggleUnread(context: context, session: session),
    );
  }
}
