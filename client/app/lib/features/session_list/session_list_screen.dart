import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/routing/app_router.dart";
import "archived_sessions_artwork.dart";

class const SessionListScreen({
  super.key,
  required final String projectId,
  required final String? projectName,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const actionDispatcher = SessionListActionDispatcher(onSessionDeleted: closeDeletedSessionRoute);
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
      onSessionTap: ({required session}) {
        context.goRoute(
          AppRoute.sessionDetail(
            projectId: projectId,
            projectName: projectName,
            sessionId: session.id,
            sessionTitle: session.title,
            readOnly: false,
          ),
        );
      },
      actionDispatcher: actionDispatcher,
      archivedEmptyState: const SessionArchivedEmptyState(artwork: ArchivedSessionsArtwork()),
      connectionBanner: ConnectionBanner.maybeFor(context),
    );
  }
}

/// Leaves a deleted session's detail/diffs route when that session is still
/// the current mobile location. In a narrow list route this is a no-op.
void closeDeletedSessionRoute({required BuildContext context, required String sessionId}) {
  final routeState = GoRouterState.of(context);
  if (routeState.pathParameters[sessionIdPathParam] != sessionId) return;

  final projectId = routeState.pathParameters[projectIdPathParam];
  if (projectId == null) return;

  context.goRoute(
    AppRoute.sessions(
      projectId: projectId,
      projectName: routeState.uri.queryParameters[projectNameQueryParam],
    ),
  );
}
