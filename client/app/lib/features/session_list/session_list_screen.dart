import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/routing/app_router.dart";
import "session_list_action_dispatcher.dart";
import "session_list_scaffold.dart";

class const SessionListScreen({
  super.key,
  required final String projectId,
  final String? projectName,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SessionListBody(
      projectId: projectId,
      projectName: projectName,
    );
  }
}

class const _SessionListBody({required final String projectId, final String? projectName}) extends StatelessWidget {
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
            bridgeId: null,
          ),
        );
      },
      sessionMenuEntries: (BuildContext context, Session session) =>
          actionDispatcher.sessionMenuEntries(context: context, session: session),
    );
  }
}
