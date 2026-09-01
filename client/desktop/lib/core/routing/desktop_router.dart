import "dart:async";

import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../features/auth_gate/auth_gate.dart";
import "../../features/home/desktop_home.dart";
import "../../features/settings/desktop_harnesses_settings_screen.dart";
import "../../features/settings/desktop_profile_screen.dart";
import "../../features/settings/desktop_settings_screen.dart";

/// Root navigator shared by desktop routes and app-wide presentation hosts.
final GlobalKey<NavigatorState> desktopRootNavigatorKey = GlobalKey<NavigatorState>();

/// Desktop routes delivered by the settings and harness-management slice.
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
            onOpenSettings: () => _goRoute(context: context, route: const AppRoute.settings()),
          ),
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
          builder: (BuildContext context, GoRouterState state) => const DesktopProfileScreen(
            onClose: _goDesktopHome,
            onLogoutCompleted: _goDesktopHome,
          ),
        ),
        GoRoute(
          path: AppRouteDef.settingsHarnesses.path,
          builder: (BuildContext context, GoRouterState state) => const DesktopHarnessesSettingsScreen(
            onClose: _goDesktopHome,
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
