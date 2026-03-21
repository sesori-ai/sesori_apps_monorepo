import "package:flutter/widgets.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../features/login/login_screen.dart";
import "../../features/project_list/project_list_screen.dart";
import "../../features/session_detail/session_detail_screen.dart";
import "../../features/session_list/session_list_screen.dart";
import "../di/injection.dart";

extension AppRouteToGoRoute on AppRoute {
  /// Returns the [GoRoute] for this route with an exhaustive builder switch.
  ///
  /// Adding a new [AppRoute] value without handling it here will cause a
  /// compile-time error.
  GoRoute toGoRoute() {
    return GoRoute(
      path: path,
      builder: (context, state) => switch (this) {
        AppRoute.login => const LoginScreen(),
        AppRoute.projects => const ProjectListScreen(),
        AppRoute.sessions => SessionListScreen(
          projectId: state.pathParameters["projectId"] ?? "",
          projectName: state.uri.queryParameters["name"],
        ),
        AppRoute.sessionDetail => SessionDetailScreen(
          sessionId: state.pathParameters["sessionId"] ?? "",
          sessionTitle: state.uri.queryParameters["title"],
          readOnly: state.uri.queryParameters["readOnly"] == "true",
        ),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Type-safe navigation extensions
// ---------------------------------------------------------------------------

extension BuildContextNavigation on BuildContext {
  void goRoute(
    AppRoute route, {
    Map<String, String>? pathParams,
    Map<String, String>? queryParams,
  }) {
    GoRouter.of(this).go(
      route.buildPath(pathParams: pathParams, queryParams: queryParams),
    );
  }

  Future<T?> pushRoute<T extends Object?>(
    AppRoute route, {
    Map<String, String>? pathParams,
    Map<String, String>? queryParams,
  }) {
    return GoRouter.of(this).push<T>(
      route.buildPath(pathParams: pathParams, queryParams: queryParams),
    );
  }
}

extension GoRouterNavigation on GoRouter {
  void goRoute(
    AppRoute route, {
    Map<String, String>? pathParams,
    Map<String, String>? queryParams,
  }) {
    go(route.buildPath(pathParams: pathParams, queryParams: queryParams));
  }
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

final appRouter = GoRouter(
  initialLocation: AppRoute.login.path,
  redirect: (context, state) async {
    // Session restore: if on login and tokens exist, skip to projects
    if (state.matchedLocation == AppRoute.login.path) {
      final authRedirect = getIt<AuthRedirectService>();
      return (await authRedirect.tryRestoreSession())?.path;
    }

    return null;
  },
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
    loge("GoRouter could not match route: $uri");
  },
  routes: AppRoute.values.map((route) => route.toGoRoute()).toList(),
);
