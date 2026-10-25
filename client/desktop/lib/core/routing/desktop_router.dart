import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../features/auth_gate/auth_gate.dart";
import "../../features/home/desktop_home_pane.dart";
import "../../features/new_session/desktop_new_session_screen.dart";
import "../../features/session_diffs/desktop_session_diffs_screen.dart";
import "../../features/sessions/desktop_session_detail_screen.dart";
import "../../features/sessions/desktop_session_list_screen.dart";
import "../../features/settings/desktop_settings_modal.dart";
import "../di/injection.dart";
import "../widgets/desktop_cockpit_shell.dart";

/// Root navigator shared by desktop routes and app-wide presentation hosts.
final GlobalKey<NavigatorState> desktopRootNavigatorKey = GlobalKey<NavigatorState>();
final Completer<void> _desktopRouterReady = Completer<void>();
bool _desktopRouterReadyScheduled = false;

/// Completes only after the product router has mounted through its first frame.
Future<void> get desktopRouterReady => _desktopRouterReady.future;

void scheduleDesktopRouterReady() {
  if (_desktopRouterReady.isCompleted || _desktopRouterReadyScheduled) {
    return;
  }
  _desktopRouterReadyScheduled = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_desktopRouterReady.isCompleted) {
      _desktopRouterReady.complete();
    }
  });
}

const _desktopSessionActions = SessionListActionDispatcher(
  deleteConfirmation: SessionDeleteConfirmation.alert,
  // An archived session is read-only, so its open page gives way to the project.
  onSessionArchived: _closeDeletedSessionRoute,
  onSessionDeleted: _closeDeletedSessionRoute,
  onSessionMarkedUnread: null,
);

/// One routed main pane beside the sidebar, under a single authenticated shell.
/// The sidebar's shared list stays mounted across main-pane navigation; a
/// filtered list claims its project as viewed, and an open project page's own
/// claim takes over until that page closes.
final GoRouter desktopRouter = GoRouter(
  navigatorKey: desktopRootNavigatorKey,
  initialLocation: AppRouteDef.splash.path,
  routes: buildDesktopRoutes(),
);

@visibleForTesting
List<RouteBase> buildDesktopRoutes() => <RouteBase>[
  ShellRoute(
    builder: (BuildContext context, GoRouterState state, Widget child) => AuthGate(
      child: DesktopCockpitCubitProvider(
        child: Builder(
          // Root overlays must capture AuthGate and the cockpit's session
          // scope from inside their providers.
          builder: (context) => DesktopCockpitShell(
            selectedProjectId: state.pathParameters[projectIdPathParam],
            selectedSessionId: state.pathParameters[sessionIdPathParam],
            sessionActions: _desktopSessionActions,
            onOpenSession: ({required context, required project, required displayName, required session}) => _goRoute(
              context: context,
              route: AppRoute.sessionDetail(
                projectId: project.id,
                projectName: displayName,
                sessionId: session.id,
                sessionTitle: session.title,
                readOnly: session.time?.archived != null,
                fromLaunch: false,
              ),
            ),
            onNewSession: ({required context, required project, required displayName}) => _pushRoute(
              context: context,
              route: AppRoute.newSession(projectId: project.id, projectName: displayName),
            ),
            onOpenProject: ({required context, required project, required displayName}) => _goRoute(
              context: context,
              route: AppRoute.projectSessions(projectId: project.id, projectName: displayName),
            ),
            onOpenBridgeSettings: () => _openSettings(context: context, initialTab: DesktopSettingsTab.bridge),
            // Pushed over the page it opened from, which its close returns to.
            onOpenArchived: () {
              if (state.uri.path == AppRouteDef.archivedSessions.path) return;
              _pushRoute(context: context, route: const AppRoute.archivedSessions());
            },
            onOpenSettings: () => _openSettings(context: context, initialTab: DesktopSettingsTab.general),
            onGoBack: () => _goBack(context: context),
            child: Builder(
              builder: (context) => SessionDetailRouteVisibility(
                isVisible: ModalRoute.isCurrentOf(context) ?? false,
                child: _withPageFade(context: context, child: child),
              ),
            ),
          ),
        ),
      ),
    ),
    routes: <RouteBase>[
      GoRoute(
        path: AppRouteDef.splash.path,
        redirect: (_, _) => const AppRoute.home().buildPath(),
      ),
      GoRoute(
        path: AppRouteDef.home.path,
        builder: (BuildContext context, GoRouterState state) => DesktopHomePane(
          onOpenSession: ({required context, required project, required displayName, required session}) => _goRoute(
            context: context,
            route: AppRoute.sessionDetail(
              projectId: project.id,
              projectName: displayName,
              sessionId: session.id,
              sessionTitle: session.title,
              readOnly: false,
              fromLaunch: false,
            ),
          ),
          onOpenProject: ({required context, required project, required displayName}) => _goRoute(
            context: context,
            route: AppRoute.projectSessions(projectId: project.id, projectName: displayName),
          ),
          onOpenHarnessSettings: () => _openSettings(context: context, initialTab: DesktopSettingsTab.harnesses),
          onManageComputers: () => unawaited(
            showDesktopComputersSettings(context: context, onLogoutCompleted: _goDesktopHome),
          ),
        ),
      ),
      GoRoute(
        path: AppRouteDef.projectSessions.path,
        builder: (BuildContext context, GoRouterState state) {
          final route = _decodeSessionsRoute(state: state);
          return DesktopSessionListCubitProvider(
            key: ValueKey("desktop-session-list-cubit-${route.projectId}"),
            projectId: route.projectId,
            child: DesktopSessionListScreen(
              projectName: route.projectName,
              onSessionTap: ({required session}) => _goRoute(
                context: context,
                route: AppRoute.sessionDetail(
                  projectId: route.projectId,
                  projectName: route.projectName,
                  sessionId: session.id,
                  sessionTitle: session.title,
                  readOnly: session.time?.archived != null,
                  fromLaunch: false,
                ),
              ),
              actionDispatcher: _desktopSessionActions,
              onNewSession: () => _pushRoute(
                context: context,
                route: AppRoute.newSession(projectId: route.projectId, projectName: route.projectName),
              ),
              onOpenHarnessSettings: () => _openSettings(context: context, initialTab: DesktopSettingsTab.harnesses),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRouteDef.archivedSessions.path,
        builder: (BuildContext context, GoRouterState state) => BlocProvider(
          // Archived reads the sidebar's shared filter (D6).
          create: (context) => createAllSessionsCubit(
            context: context,
            mode: AllSessionsMode.archived,
            filterTracker: getIt<SessionListFilterTracker>(),
            sessionListService: getIt<SessionListService>(),
            projectViewingService: getIt<ProjectViewingService>(),
          ),
          child: ArchivedSessionsView(
            emptyState: const SessionArchivedEmptyState(artwork: null),
            // The connection pill and the sidebar's recovery card already say so.
            disconnectedBuilder: ({required context, required state}) => const SliverToBoxAdapter(),
            onClose: () => _popRouteOrGo(context: context, fallback: const AppRoute.home()),
            onSessionTap: ({required row}) => _pushRoute(
              context: context,
              route: AppRoute.sessionDetail(
                projectId: row.project.id,
                projectName: projectDisplayName(loc: context.loc, project: row.project),
                sessionId: row.session.id,
                sessionTitle: row.session.title,
                readOnly: true,
                fromLaunch: false,
              ),
            ),
            actionDispatcher: const SessionListActionDispatcher(
              deleteConfirmation: SessionDeleteConfirmation.alert,
              onSessionArchived: null,
              onSessionDeleted: null,
              onSessionMarkedUnread: null,
            ),
            createActionCubit: ({required projectId, required session}) => createSessionListCubit(
              locator: getIt,
              projectId: projectId,
              mode: SessionListMode.actions(sessions: [session]),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRouteDef.newSession.path,
        // Every desktop entry names its project; one without goes home.
        redirect: (_, state) =>
            _decodeNewSessionRoute(state: state).projectId == null ? const AppRoute.home().buildPath() : null,
        builder: (BuildContext context, GoRouterState state) {
          final route = _decodeNewSessionRoute(state: state);
          final projectId = route.projectId ?? (throw StateError("A new session without a project redirects home"));
          return DesktopNewSessionScreen(
            // Replacing the route reuses the page, so the key is what gives
            // another project its own cubit.
            key: ValueKey("desktop-new-session-$projectId"),
            onProjectSelected: ({required projectId, required projectName}) => _replaceRoute(
              context: context,
              route: AppRoute.newSession(projectId: projectId, projectName: projectName),
            ),
            projectId: projectId,
            projectName: route.projectName,
            onBack: () => _popRouteOrGo(
              context: context,
              fallback: AppRoute.projectSessions(projectId: projectId, projectName: route.projectName),
            ),
            onOpenProject: () => _goRoute(
              context: context,
              route: AppRoute.projectSessions(projectId: projectId, projectName: route.projectName),
            ),
            onOpenHarnessSettings: () => _openSettings(context: context, initialTab: DesktopSettingsTab.harnesses),
            onSessionCreated: ({required session}) => _replaceRoute(
              context: context,
              route: AppRoute.sessionDetail(
                projectId: projectId,
                projectName: route.projectName,
                sessionId: session.id,
                sessionTitle: session.title,
                readOnly: false,
                fromLaunch: false,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRouteDef.sessionDetail.path,
        builder: (BuildContext context, GoRouterState state) {
          final route = _decodeSessionDetailRoute(state: state);
          return DesktopSessionDetailScreen(
            key: ValueKey((projectId: route.projectId, sessionId: route.sessionId)),
            projectId: route.projectId,
            sessionId: route.sessionId,
            sessionTitle: route.sessionTitle,
            readOnly: route.readOnly,
            projectName: route.projectName,
            onOpenProject: () => _goRoute(
              context: context,
              route: AppRoute.projectSessions(projectId: route.projectId, projectName: route.projectName),
            ),
            // A subtask pushed over its parent pops back there with the transcript kept; one reached
            // any other way (the sidebar, a notification) opens its parent.
            onOpenParentSession: ({required parentSessionId}) {
              final parent = AppRoute.sessionDetail(
                projectId: route.projectId,
                projectName: route.projectName,
                sessionId: parentSessionId,
                sessionTitle: null,
                readOnly: false,
                fromLaunch: false,
              );
              if (_pageBelowIs(context: context, route: parent)) {
                context.pop();
              } else {
                _goRoute(context: context, route: parent);
              }
            },
            onShowDiffs: () => _pushRoute(
              context: context,
              route: AppRoute.sessionDiffs(
                projectId: route.projectId,
                projectName: route.projectName,
                sessionId: route.sessionId,
              ),
            ),
            onOpenHarnessSettings: () => _openSettings(context: context, initialTab: DesktopSettingsTab.harnesses),
            onOpenBridgeSettings: () => _openSettings(context: context, initialTab: DesktopSettingsTab.bridge),
            sessionActions: _desktopSessionActions,
            onMarkedUnread: () => _goRoute(
              context: context,
              route: AppRoute.projectSessions(projectId: route.projectId, projectName: route.projectName),
            ),
            onOpenSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) =>
                _pushRoute(
                  context: context,
                  route: AppRoute.sessionDetail(
                    projectId: projectId,
                    projectName: route.projectName,
                    sessionId: sessionId,
                    sessionTitle: sessionTitle,
                    readOnly: readOnly,
                    fromLaunch: false,
                  ),
                ),
          );
        },
      ),
      GoRoute(
        path: AppRouteDef.sessionDiffs.path,
        builder: (BuildContext context, GoRouterState state) {
          final route = _decodeSessionDiffsRoute(state: state);
          return DesktopSessionDiffsScreen(
            key: ValueKey((projectId: route.projectId, sessionId: route.sessionId)),
            projectName: route.projectName,
            sessionId: route.sessionId,
            onOpenProject: () => _goRoute(
              context: context,
              route: AppRoute.projectSessions(projectId: route.projectId, projectName: route.projectName),
            ),
          );
        },
      ),
    ],
  ),
];

/// Main-pane pages cross-fade in place, the way desktop apps swap content; the
/// sidebar never moves. Reduced motion switches instantly.
Widget _withPageFade({required BuildContext context, required Widget child}) {
  final fade = prefersReducedMotion(context)
      ? const _PageFade(transitionDuration: Duration.zero)
      : const _PageFade(transitionDuration: Duration(milliseconds: 150));
  return Theme(
    data: Theme.of(context).copyWith(
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {for (final platform in TargetPlatform.values) platform: fade},
      ),
    ),
    child: child,
  );
}

class const _PageFade({@override required final Duration transitionDuration}) extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);
}

AppRouteProjectSessions _decodeSessionsRoute({required GoRouterState state}) {
  return switch (AppRoute.fromDef(
    def: AppRouteDef.projectSessions,
    pathParams: state.pathParameters,
    queryParams: state.uri.queryParameters,
  )) {
    final AppRouteProjectSessions route => route,
    final route => throw StateError("Route ${route.def.name} is not a project-sessions route"),
  };
}

AppRouteNewSession _decodeNewSessionRoute({required GoRouterState state}) {
  return switch (AppRoute.fromDef(
    def: AppRouteDef.newSession,
    pathParams: state.pathParameters,
    queryParams: state.uri.queryParameters,
  )) {
    final AppRouteNewSession route => route,
    final route => throw StateError("Route ${route.def.name} is not a new-session route"),
  };
}

AppRouteSessionDetail _decodeSessionDetailRoute({required GoRouterState state}) {
  return switch (AppRoute.fromDef(
    def: AppRouteDef.sessionDetail,
    pathParams: state.pathParameters,
    queryParams: state.uri.queryParameters,
  )) {
    final AppRouteSessionDetail route => route,
    final route => throw StateError("Route ${route.def.name} is not a session-detail route"),
  };
}

AppRouteSessionDiffs _decodeSessionDiffsRoute({required GoRouterState state}) {
  return switch (AppRoute.fromDef(
    def: AppRouteDef.sessionDiffs,
    pathParams: state.pathParameters,
    queryParams: state.uri.queryParameters,
  )) {
    final AppRouteSessionDiffs route => route,
    final route => throw StateError("Route ${route.def.name} is not a session-diffs route"),
  };
}

void _openSettings({required BuildContext context, required DesktopSettingsTab initialTab}) {
  unawaited(
    showDesktopSettingsModal(
      context: context,
      initialTab: initialTab,
      onLogoutCompleted: _goDesktopHome,
    ),
  );
}

void _closeDeletedSessionRoute({required BuildContext context, required String sessionId}) {
  // The list's context need not belong to the current detail route.
  // ignore: no_slop_linter/avoid_raw_go_router, reads current route state inside the typed routing boundary
  final routeState = GoRouter.of(context).state;
  if (routeState.pathParameters[sessionIdPathParam] != sessionId) {
    return;
  }
  final projectId = routeState.pathParameters[projectIdPathParam];
  if (projectId == null) {
    return;
  }
  _goRoute(
    context: context,
    route: AppRoute.projectSessions(
      projectId: projectId,
      projectName: routeState.uri.queryParameters[projectNameQueryParam],
    ),
  );
}

void _goDesktopHome() {
  // ignore: no_slop_linter/avoid_raw_go_router, desktop router's typed route boundary
  desktopRouter.go(const AppRoute.home().buildPath());
}

void _goRoute({required BuildContext context, required AppRoute route}) {
  // ignore: no_slop_linter/avoid_raw_go_router, desktop router's typed route boundary
  GoRouter.of(context).go(route.buildPath());
}

void _pushRoute({required BuildContext context, required AppRoute route}) {
  // ignore: no_slop_linter/avoid_raw_go_router, desktop router's typed route boundary
  unawaited(GoRouter.of(context).push<void>(route.buildPath()));
}

void _replaceRoute({required BuildContext context, required AppRoute route}) {
  // ignore: no_slop_linter/avoid_raw_go_router, desktop router's typed route boundary
  GoRouter.of(context).replace<void>(route.buildPath());
}

void _popRouteOrGo({required BuildContext context, required AppRoute fallback}) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  _goRoute(context: context, route: fallback);
}

/// Whether the page under the current one is [route], so popping lands on it.
bool _pageBelowIs({required BuildContext context, required AppRoute route}) {
  Iterable<RouteMatchBase> pages(List<RouteMatchBase> matches) =>
      matches.expand((match) => match is ShellRouteMatch ? pages(match.matches) : [match]);
  // ignore: no_slop_linter/avoid_raw_go_router, desktop router's typed route boundary
  final stack = pages(GoRouter.of(context).routerDelegate.currentConfiguration.matches).toList();
  return stack.length >= 2 && stack[stack.length - 2].matchedLocation == Uri.parse(route.buildPath()).path;
}

/// Goes back as a system back would: the page is asked first, so one with a
/// screen open over it, such as Prompts, closes that screen instead of leaving.
void _goBack({required BuildContext context}) {
  // ignore: no_slop_linter/avoid_raw_go_router, desktop router's typed route boundary
  unawaited(GoRouter.of(context).routerDelegate.popRoute());
}
