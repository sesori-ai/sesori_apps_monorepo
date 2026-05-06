import "package:flutter/widgets.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../features/login/login_screen.dart";
import "../../features/new_session/new_session_screen.dart";
import "../../features/project_list/project_list_screen.dart";
import "../../features/session_detail/session_detail_screen.dart";
import "../../features/session_diffs/session_diffs_screen.dart";
import "../../features/session_list/session_list_screen.dart";
import "../../features/settings/settings_screen.dart";
import "../../features/splash/splash_screen.dart";

extension AppRouteToGoRoute on AppRouteDef {
  /// Returns the [GoRoute] for this route definition with an exhaustive
  /// builder switch over decoded [AppRoute] values.
  GoRoute toGoRoute() {
    return GoRoute(
      path: path,
      builder: (context, state) {
        final route = AppRoute.fromDef(
          def: this,
          pathParams: state.pathParameters,
          queryParams: state.uri.queryParameters,
        );

        return switch (route) {
          AppRouteSplash() => const SplashScreen(),
          AppRouteLogin() => const LoginScreen(),
          AppRouteProjects() => const ProjectListScreen(),
          AppRouteSettings() => const SettingsScreen(),
          AppRouteSessions(:final projectId, :final projectName) => SessionListScreen(
            projectId: projectId,
            projectName: projectName,
          ),
          AppRouteNewSession(:final projectId) => NewSessionScreen(
            projectId: projectId,
          ),
          AppRouteSessionDetail(:final projectId, :final sessionId, :final sessionTitle, :final readOnly) =>
            SessionDetailScreen(
              projectId: projectId,
              sessionId: sessionId,
              sessionTitle: sessionTitle,
              readOnly: readOnly,
            ),
          AppRouteSessionDiffs(:final projectId, :final sessionId) => SessionDiffsScreen(
            projectId: projectId,
            sessionId: sessionId,
          ),
        };
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Type-safe navigation extensions
// ---------------------------------------------------------------------------

extension BuildContextNavigation on BuildContext {
  void goRoute(AppRoute route) {
    // ignore: no_slop_linter/avoid_raw_go_router, typed wrapper implementation
    GoRouter.of(this).go(route.buildPath());
  }

  Future<T?> pushRoute<T extends Object?>(AppRoute route) {
    // ignore: no_slop_linter/avoid_raw_go_router, typed wrapper implementation
    return GoRouter.of(this).push<T>(route.buildPath());
  }
}

extension GoRouterNavigation on GoRouter {
  void goRoute(AppRoute route) {
    go(route.buildPath());
  }
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

final appRouter = GoRouter(
  initialLocation: AppRouteDef.splash.path,
  onException: (context, state, router) {
    // Deep links (e.g. com.sesori.app://auth/callback) are handled
    // entirely by DeepLinkService via app_links — no GoRouter navigation
    // needed. We just suppress the error so GoRouter stays on the current
    // page while app_links processes the callback and navigates.
    final uri = state.uri;
    if (uri.scheme == bundleId) {
      logd("GoRouter ignoring deep link (handled by app_links): $uri");
      return;
    }

    // Unexpected routing error — log it. GoRouter stays on the current page.
    loge("GoRouter could not match route: ${uri.toString()}");
  },
  routes: AppRouteDef.values.map((def) => def.toGoRoute()).toList(),
);
