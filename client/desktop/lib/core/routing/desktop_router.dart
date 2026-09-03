import "dart:async";

import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../features/auth_gate/auth_gate.dart";
import "../../features/home/desktop_home.dart";
import "../../features/new_session/desktop_new_session_screen.dart";
import "../../features/projects/desktop_project_list_screen.dart";
import "../../features/session_diffs/desktop_session_diffs_screen.dart";
import "../../features/sessions/desktop_session_detail_screen.dart";
import "../../features/sessions/desktop_session_list_screen.dart";
import "../../features/settings/desktop_harnesses_settings_screen.dart";
import "../../features/settings/desktop_profile_screen.dart";
import "../../features/settings/desktop_settings_screen.dart";
import "../di/injection.dart";
import "../widgets/desktop_cockpit_shell.dart";

/// Root navigator shared by desktop routes and app-wide presentation hosts.
final GlobalKey<NavigatorState> desktopRootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _desktopSessionNavigatorKey = GlobalKey<NavigatorState>();

const _sessionsRouteSegment = ":$projectIdPathParam/sessions";
const _newSessionRouteSegment = "new";
const _sessionDetailRouteSegment = ":$sessionIdPathParam";
const _sessionDiffsRouteSegment = "diffs";
const _desktopSessionActions = SessionListActionDispatcher(onSessionDeleted: _closeDeletedSessionRoute);

/// Desktop routes delivered through the shared adaptive cockpit slices.
///
/// [AuthGate] owns one authenticated session above the product-specific
/// sidebar. A project-scoped nested shell then owns one session-list cubit and
/// keeps that inventory mounted while the right pane navigates.
final GoRouter desktopRouter = GoRouter(
  navigatorKey: desktopRootNavigatorKey,
  initialLocation: AppRouteDef.splash.path,
  routes: buildDesktopRoutes(),
);

@visibleForTesting
List<RouteBase> buildDesktopRoutes() => <RouteBase>[
  ShellRoute(
    builder: (BuildContext context, GoRouterState state, Widget child) => AuthGate(
      child: DesktopCockpitShell(
        destination: _destinationFor(path: state.uri.path),
        onOpenBridge: () => _goRoute(context: context, route: const AppRoute.splash()),
        onOpenProjects: () => _goRoute(context: context, route: const AppRoute.projects()),
        onOpenSettings: () => _openSettings(context: context, currentPath: state.uri.path),
        child: child,
      ),
    ),
    routes: <RouteBase>[
      GoRoute(
        path: AppRouteDef.splash.path,
        builder: (BuildContext context, GoRouterState state) => DesktopHome(
          onOpenProjects: () => _goRoute(context: context, route: const AppRoute.projects()),
          onOpenSettings: () => _openSettings(context: context, currentPath: state.uri.path),
        ),
      ),
      GoRoute(
        path: AppRouteDef.projects.path,
        builder: (BuildContext context, GoRouterState state) => DesktopProjectListScreen(
          onOpenSettings: () => _openSettings(context: context, currentPath: state.uri.path),
          onOpenProject: ({required projectId, required projectName}) => _goRoute(
            context: context,
            route: AppRoute.sessions(projectId: projectId, projectName: projectName),
          ),
        ),
        routes: <RouteBase>[
          ShellRoute(
            navigatorKey: _desktopSessionNavigatorKey,
            builder: (BuildContext context, GoRouterState state, Widget child) {
              final projectId = state.pathParameters[projectIdPathParam];
              if (projectId == null) {
                throw StateError("A desktop session route is missing its project id");
              }
              final projectName = state.uri.queryParameters[projectNameQueryParam];
              final selectedSessionId = state.pathParameters[sessionIdPathParam];

              return DesktopSessionListCubitProvider(
                key: ValueKey("desktop-session-list-cubit-$projectId"),
                projectId: projectId,
                child: SessionSplitShell(
                  projectViewingService: getIt<ProjectViewingService>(),
                  list: DesktopSessionListPane(
                    projectName: projectName,
                    selectedSessionId: selectedSessionId,
                    onBack: () => _goRoute(context: context, route: const AppRoute.projects()),
                    onSessionTap: ({required session}) => _goRoute(
                      context: context,
                      route: AppRoute.sessionDetail(
                        projectId: projectId,
                        projectName: projectName,
                        sessionId: session.id,
                        sessionTitle: session.title,
                        readOnly: false,
                      ),
                    ),
                    onNewSession: () => _pushRoute(
                      context: context,
                      route: AppRoute.newSession(projectId: projectId, projectName: projectName),
                    ),
                    actionDispatcher: _desktopSessionActions,
                  ),
                  child: child,
                ),
              );
            },
            routes: <RouteBase>[
              GoRoute(
                path: _sessionsRouteSegment,
                builder: (BuildContext context, GoRouterState state) {
                  final route = _decodeSessionsRoute(state: state);
                  return Builder(
                    builder: (context) => SessionSplitScope.of(context).isSplit
                        ? const EmptySessionDetailPanel(
                            background: null,
                            connectionBanner: null,
                          )
                        : DesktopSessionListScreen(
                            projectName: route.projectName,
                            onBack: () => _goRoute(context: context, route: const AppRoute.projects()),
                            onSessionTap: ({required session}) => _goRoute(
                              context: context,
                              route: AppRoute.sessionDetail(
                                projectId: route.projectId,
                                projectName: route.projectName,
                                sessionId: session.id,
                                sessionTitle: session.title,
                                readOnly: false,
                              ),
                            ),
                            onNewSession: () => _pushRoute(
                              context: context,
                              route: AppRoute.newSession(
                                projectId: route.projectId,
                                projectName: route.projectName,
                              ),
                            ),
                            actionDispatcher: _desktopSessionActions,
                          ),
                  );
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: _newSessionRouteSegment,
                    builder: (BuildContext context, GoRouterState state) {
                      final route = _decodeNewSessionRoute(state: state);
                      return DesktopNewSessionScreen(
                        projectId: route.projectId,
                        projectName: route.projectName,
                        onBack: () => _popRouteOrGo(
                          context: context,
                          fallback: AppRoute.sessions(
                            projectId: route.projectId,
                            projectName: route.projectName,
                          ),
                        ),
                        onOpenHarnessSettings: () => _pushRoute(
                          context: context,
                          route: const AppRoute.settingsHarnesses(
                            presentation: HarnessSettingsPresentation.modal,
                          ),
                        ),
                        onSessionCreated: ({required session}) => _replaceRoute(
                          context: context,
                          route: AppRoute.sessionDetail(
                            projectId: route.projectId,
                            projectName: route.projectName,
                            sessionId: session.id,
                            sessionTitle: session.title,
                            readOnly: false,
                          ),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: _sessionDetailRouteSegment,
                    builder: (BuildContext context, GoRouterState state) {
                      final route = _decodeSessionDetailRoute(state: state);
                      return DesktopSessionDetailScreen(
                        key: ValueKey((projectId: route.projectId, sessionId: route.sessionId)),
                        projectId: route.projectId,
                        sessionId: route.sessionId,
                        sessionTitle: route.sessionTitle,
                        readOnly: route.readOnly,
                        onBack: () => _popRouteOrGo(
                          context: context,
                          fallback: AppRoute.sessions(
                            projectId: route.projectId,
                            projectName: route.projectName,
                          ),
                        ),
                        onShowDiffs: () => _pushRoute(
                          context: context,
                          route: AppRoute.sessionDiffs(
                            projectId: route.projectId,
                            projectName: route.projectName,
                            sessionId: route.sessionId,
                          ),
                        ),
                        onOpenSession:
                            ({
                              required projectId,
                              required sessionId,
                              required sessionTitle,
                              required readOnly,
                            }) => _pushRoute(
                              context: context,
                              route: AppRoute.sessionDetail(
                                projectId: projectId,
                                projectName: route.projectName,
                                sessionId: sessionId,
                                sessionTitle: sessionTitle,
                                readOnly: readOnly,
                              ),
                            ),
                      );
                    },
                    routes: <RouteBase>[
                      GoRoute(
                        path: _sessionDiffsRouteSegment,
                        builder: (BuildContext context, GoRouterState state) {
                          final route = _decodeSessionDiffsRoute(state: state);
                          return DesktopSessionDiffsScreen(
                            key: ValueKey((projectId: route.projectId, sessionId: route.sessionId)),
                            projectId: route.projectId,
                            sessionId: route.sessionId,
                            onBack: () => _popRouteOrGo(
                              context: context,
                              fallback: AppRoute.sessionDetail(
                                projectId: route.projectId,
                                projectName: route.projectName,
                                sessionId: route.sessionId,
                                sessionTitle: null,
                                readOnly: false,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRouteDef.settings.path,
        builder: (BuildContext context, GoRouterState state) => DesktopSettingsScreen(
          onClose: () => _popRoute(context: context),
          onOpenProfile: () => _pushRoute(context: context, route: const AppRoute.settingsProfile()),
          onOpenHarnesses: () => _pushRoute(
            context: context,
            route: const AppRoute.settingsHarnesses(
              presentation: HarnessSettingsPresentation.pushed,
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRouteDef.settingsProfile.path,
        builder: (BuildContext context, GoRouterState state) => DesktopProfileScreen(
          onClose: () => _popRoute(context: context),
          onLogoutCompleted: _goDesktopHome,
        ),
      ),
      GoRoute(
        path: AppRouteDef.settingsHarnesses.path,
        builder: (BuildContext context, GoRouterState state) {
          final route = switch (AppRoute.fromDef(
            def: AppRouteDef.settingsHarnesses,
            pathParams: state.pathParameters,
            queryParams: state.uri.queryParameters,
          )) {
            final AppRouteSettingsHarnesses route => route,
            final route => throw StateError("Route ${route.def.name} is not a harness-settings route"),
          };
          return DesktopHarnessesSettingsScreen(
            presentation: route.presentation,
            onClose: () => _popRoute(context: context),
          );
        },
      ),
    ],
  ),
];

AppRouteSessions _decodeSessionsRoute({required GoRouterState state}) {
  return switch (AppRoute.fromDef(
    def: AppRouteDef.sessions,
    pathParams: state.pathParameters,
    queryParams: state.uri.queryParameters,
  )) {
    final AppRouteSessions route => route,
    final route => throw StateError("Route ${route.def.name} is not a sessions route"),
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

DesktopCockpitDestination _destinationFor({required String path}) {
  if (isDesktopSettingsPath(path: path)) {
    return DesktopCockpitDestination.settings;
  }
  if (path.startsWith(AppRouteDef.projects.path)) {
    return DesktopCockpitDestination.projects;
  }
  return DesktopCockpitDestination.bridge;
}

@visibleForTesting
bool isDesktopSettingsPath({required String path}) {
  return path == AppRouteDef.settings.path || path.startsWith("${AppRouteDef.settings.path}/");
}

void _openSettings({required BuildContext context, required String currentPath}) {
  if (isDesktopSettingsPath(path: currentPath)) {
    return;
  }
  _pushRoute(context: context, route: const AppRoute.settings());
}

void _closeDeletedSessionRoute({required BuildContext context, required String sessionId}) {
  final routeState = GoRouterState.of(context);
  if (routeState.pathParameters[sessionIdPathParam] != sessionId) {
    return;
  }
  final projectId = routeState.pathParameters[projectIdPathParam];
  if (projectId == null) {
    return;
  }
  _goRoute(
    context: context,
    route: AppRoute.sessions(
      projectId: projectId,
      projectName: routeState.uri.queryParameters[projectNameQueryParam],
    ),
  );
}

void _goDesktopHome() {
  // ignore: no_slop_linter/avoid_raw_go_router, desktop router's typed route boundary
  desktopRouter.go(const AppRoute.splash().buildPath());
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

void _popRoute({required BuildContext context}) {
  // ignore: no_slop_linter/avoid_raw_go_router, desktop router's typed route boundary
  final GoRouter router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
    return;
  }
  _goDesktopHome();
}
