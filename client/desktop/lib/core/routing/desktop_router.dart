import "dart:async";

import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../features/auth_gate/auth_gate.dart";
import "../../features/home/desktop_home.dart";
import "../../features/projects/desktop_project_list_screen.dart";
import "../../features/sessions/desktop_session_list_screen.dart";
import "../../features/settings/desktop_harnesses_settings_screen.dart";
import "../../features/settings/desktop_profile_screen.dart";
import "../../features/settings/desktop_settings_screen.dart";

/// Root navigator shared by desktop routes and app-wide presentation hosts.
final GlobalKey<NavigatorState> desktopRootNavigatorKey = GlobalKey<NavigatorState>();

/// Desktop routes delivered through the project/session-list slice.
///
/// [AuthGate] wraps the whole signed-in route set so every destination keeps
/// the same auth/session owner while navigation changes the child view.
final GoRouter desktopRouter = GoRouter(
  navigatorKey: desktopRootNavigatorKey,
  initialLocation: AppRouteDef.splash.path,
  routes: <RouteBase>[
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) => AuthGate(child: child),
      routes: <RouteBase>[
        GoRoute(
          path: AppRouteDef.splash.path,
          builder: (BuildContext context, GoRouterState state) => DesktopHome(
            onOpenProjects: () => _goRoute(context: context, route: const AppRoute.projects()),
            onOpenSettings: () => _goRoute(context: context, route: const AppRoute.settings()),
          ),
        ),
        GoRoute(
          path: AppRouteDef.projects.path,
          builder: (BuildContext context, GoRouterState state) => DesktopProjectListScreen(
            onOpenSettings: () => _goRoute(context: context, route: const AppRoute.settings()),
            onOpenProject: ({required projectId, required projectName}) => _goRoute(
              context: context,
              route: AppRoute.sessions(projectId: projectId, projectName: projectName),
            ),
          ),
        ),
        GoRoute(
          path: AppRouteDef.sessions.path,
          builder: (BuildContext context, GoRouterState state) {
            final route = switch (AppRoute.fromDef(
              def: AppRouteDef.sessions,
              pathParams: state.pathParameters,
              queryParams: state.uri.queryParameters,
            )) {
              final AppRouteSessions route => route,
              final route => throw StateError("Route ${route.def.name} is not a sessions route"),
            };
            return DesktopSessionListScreen(
              projectId: route.projectId,
              projectName: route.projectName,
              onBack: () => _goRoute(context: context, route: const AppRoute.projects()),
            );
          },
        ),
        GoRoute(
          path: AppRouteDef.settings.path,
          builder: (BuildContext context, GoRouterState state) => DesktopSettingsScreen(
            onClose: _goDesktopHome,
            onOpenProfile: () => _pushRoute(context: context, route: const AppRoute.settingsProfile()),
            onOpenHarnesses: () => _pushRoute(
              context: context,
              route: const AppRoute.settingsHarnesses(presentation: HarnessSettingsPresentation.pushed),
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
          builder: (BuildContext context, GoRouterState state) => DesktopHarnessesSettingsScreen(
            onClose: () => _popRoute(context: context),
          ),
        ),
      ],
    ),
  ],
);

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

void _popRoute({required BuildContext context}) {
  // ignore: no_slop_linter/avoid_raw_go_router, desktop router's typed route boundary
  final GoRouter router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
    return;
  }
  _goDesktopHome();
}
