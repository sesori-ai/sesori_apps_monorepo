import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/routing/app_router.dart";
import "onboarding/bridge_onboarding.dart";

/// The phone's home: the session list across projects, with CLI install and
/// share guidance and relay reconnection while the computer is not connected.
class const HomeScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _HomeView(
    presentation: SessionsHomePage(
      onOpenSettings: ({required context}) => context.pushRoute(const AppRoute.settings()),
      connectionBannerBuilder: ({required context}) => ConnectionBanner.maybeFor(context),
      onSwitchComputer: switchComputer,
      onManageComputers: manageComputers,
    ),
    onNewSession: ({required context, required projectId, required projectName}) =>
        context.pushRoute(AppRoute.newSession(projectId: projectId, projectName: projectName)),
  );
}

/// The wide layout's sidebar body: the home's list beside the open page.
/// [HomeSidebarFooter] holds the computer switcher and Settings.
class const HomeSidebar({
  super.key,

  /// The session the content pane beside the list shows, if any.
  required final String? selectedSessionId,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _HomeView(
    presentation: SessionsHomeSidebar(selectedSessionId: selectedSessionId),
    // Beside the sidebar, the home's pane is the composer.
    onNewSession: ({required context, required projectId, required projectName}) =>
        context.goRoute(const AppRoute.home()),
  );
}

/// The list's wiring, the same on the page and in the sidebar.
class const _HomeView({
  required final SessionsHomePresentation presentation,
  required final HomeNewSessionCallback onNewSession,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SessionsHomeView(
    presentation: presentation,
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
      sessions: [session],
    ),
    onNewSession: onNewSession,
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
    onRefreshDisconnected: ({required context, required state}) => context.read<ProjectListCubit>().reconnectBridge(),
  );
}
