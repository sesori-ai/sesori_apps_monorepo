import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/routing/app_router.dart";
import "onboarding/bridge_onboarding.dart";

/// The phone's home, or the wide layout's sidebar: the session list across
/// projects, with CLI install and share guidance and relay reconnection while
/// the computer is not connected.
class const HomeScreen({
  super.key,
  required final SessionsHomePresentation presentation,

  /// The session the content pane beside the list shows, if any.
  required final String? selectedSessionId,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SessionsHomeView(
    presentation: presentation,
    selectedSessionId: selectedSessionId,
    onSessionTap: ({required row}) => context.goRoute(
      AppRoute.sessionDetail(
        projectId: row.project.id,
        projectName: projectDisplayName(loc: context.loc, project: row.project),
        sessionId: row.session.id,
        sessionTitle: row.session.title,
        readOnly: false,
        fromLaunch: false,
      ),
    ),
    actionDispatcher: const SessionListActionDispatcher(
      deleteConfirmation: SessionDeleteConfirmation.sheet,
      // Beside the list from 700 pt, an archived open session leaves the pane.
      onSessionArchived: closeDeletedSessionRoute,
      onSessionDeleted: closeDeletedSessionRoute,
      onSessionMarkedUnread: null,
    ),
    createActionCubit: ({required projectId, required session}) => createSessionListCubit(
      locator: getIt,
      projectId: projectId,
      mode: SessionListMode.actions(sessions: [session]),
    ),
    onNewSession: ({required context, required projectId, required projectName}) => switch (presentation) {
      SessionsHomePresentation.page => context.pushRoute(
        AppRoute.newSession(projectId: projectId, projectName: projectName),
      ),
      // Beside the sidebar, the home's pane is the composer.
      SessionsHomePresentation.sidebar => context.goRoute(const AppRoute.home()),
    },
    onOpenArchived: ({required context}) => context.pushRoute(const AppRoute.archivedSessions()),
    onOpenSettings: ({required context}) => context.pushRoute(const AppRoute.settings()),
    // Settings goes under the page so Back from Computers lands there.
    onManageComputers: ({required context}) {
      context.pushRoute(const AppRoute.settings());
      context.pushRoute(const AppRoute.settingsComputers());
    },
    disconnectedBuilder: ({required context, required state}) => DisconnectedComputerSlivers(state: state),
    noProjectsState: Builder(
      builder: (context) => ConnectedEmptyView(
        onAddProject: () => unawaited(
          showAddProjectDialog(
            context: context,
            // A first project's next step is its first session.
            onProjectAdded: ({required context, required project, required displayName}) =>
                context.pushRoute(AppRoute.newSession(projectId: project.id, projectName: displayName)),
          ),
        ),
      ),
    ),
    connectionBannerBuilder: ({required context}) => ConnectionBanner.maybeFor(context),
    onRefreshDisconnected: ({required context, required state}) => context.read<ProjectListCubit>().reconnectBridge(),
    onSwitchComputer: switchComputer,
  );
}
