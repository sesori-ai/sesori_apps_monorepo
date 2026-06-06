import "package:flutter/widgets.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/widgets/session_split/empty_session_detail_panel.dart";
import "../../core/widgets/session_split/session_split_route_child.dart";
import "../../core/widgets/session_split/session_split_scope.dart";
import "../../core/widgets/session_split/session_split_shell.dart";
import "../../features/login/login_screen.dart";
import "../../features/new_session/new_session_screen.dart";
import "../../features/project_list/project_list_screen.dart";
import "../../features/session_detail/session_detail_screen.dart";
import "../../features/session_diffs/session_diffs_screen.dart";
import "../../features/session_list/session_list_cubit_provider.dart";
import "../../features/session_list/session_list_panel.dart";
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
          AppRouteSessions(:final projectId, :final projectName) => SessionListScreen(projectId: projectId, projectName: projectName),
          AppRouteNewSession(:final projectId) => NewSessionScreen(projectId: projectId),
          AppRouteSessionDetail(:final projectId, :final sessionId, :final sessionTitle, :final readOnly) =>
            SessionDetailScreen(projectId: projectId, sessionId: sessionId, sessionTitle: sessionTitle, readOnly: readOnly),
          AppRouteSessionDiffs(:final projectId, :final sessionId) => SessionDiffsScreen(projectId: projectId, sessionId: sessionId),
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

List<RouteBase> buildAppRoutes() {
  return [
    for (final def in AppRouteDef.values)
      if (_isFlatRoute(def)) def.toGoRoute(),
    AppRouteDef.newSession.toGoRoute(),
    ShellRoute(
      builder: (context, state, child) {
        if (child case final SessionSplitRouteChild routeChild) {
          return _SessionSplitShellHost(routeChild: routeChild);
        }

        throw StateError("Session shell child must be a SessionSplitRouteChild");
      },
      routes: [
        _sessionSplitRoute(def: AppRouteDef.sessions, routeKind: SessionSplitRouteKind.list),
        _sessionSplitRoute(def: AppRouteDef.sessionDetail, routeKind: SessionSplitRouteKind.detail),
        _sessionSplitRoute(def: AppRouteDef.sessionDiffs, routeKind: SessionSplitRouteKind.diffs),
      ],
    ),
  ];
}

bool _isFlatRoute(AppRouteDef def) {
  return switch (def) {
    AppRouteDef.splash || AppRouteDef.login || AppRouteDef.projects || AppRouteDef.settings => true,
    AppRouteDef.sessions || AppRouteDef.newSession || AppRouteDef.sessionDetail || AppRouteDef.sessionDiffs => false,
  };
}

GoRoute _sessionSplitRoute({required AppRouteDef def, required SessionSplitRouteKind routeKind}) {
  return GoRoute(
    path: def.path,
    builder: (context, state) {
      final route = AppRoute.fromDef(
        def: def,
        pathParams: state.pathParameters,
        queryParams: state.uri.queryParameters,
      );

      return SessionSplitRouteChild(
        routeKind: routeKind,
        route: route,
        child: _buildSessionSplitChild(route: route),
      );
    },
  );
}

Widget _buildSessionSplitChild({required AppRoute route}) {
  return switch (route) {
    AppRouteSessions(:final projectId, :final projectName) => SessionListScreen(projectId: projectId, projectName: projectName),
    AppRouteSessionDetail(:final projectId, :final sessionId, :final sessionTitle, :final readOnly) => Builder(
        builder: (context) {
          final splitScope = SessionSplitScope.maybeOf(context);
          return SessionDetailScreen(
            key: ValueKey("session-detail-$sessionId"),
            projectId: projectId,
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            readOnly: readOnly,
            onOpenDiffs: splitScope != null && splitScope.isSplit
                ? () => context.goRoute(AppRoute.sessionDiffs(projectId: projectId, sessionId: sessionId))
                : null,
          );
        },
      ),
    AppRouteSessionDiffs(:final projectId, :final sessionId) => SessionDiffsScreen(
        key: ValueKey("session-diffs-$sessionId"),
        projectId: projectId,
        sessionId: sessionId,
      ),
    AppRouteSplash() ||
    AppRouteLogin() ||
    AppRouteProjects() ||
    AppRouteSettings() ||
    AppRouteNewSession() => throw StateError("Route ${route.def.name} is not a session split child"),
  };
}

class _SessionSplitShellHost extends StatelessWidget {
  final SessionSplitRouteChild routeChild;

  const _SessionSplitShellHost({required this.routeChild});

  @override
  Widget build(BuildContext context) {
    final (projectId, projectName, selectedSessionId) = switch (routeChild.route) {
      AppRouteSessions(:final projectId, :final projectName) => (projectId, projectName, null),
      AppRouteSessionDetail(:final projectId, :final sessionId) || AppRouteSessionDiffs(:final projectId, :final sessionId) => (projectId, null, sessionId),
      AppRouteSplash() || AppRouteLogin() || AppRouteProjects() || AppRouteSettings() || AppRouteNewSession() =>
        throw StateError("Route ${routeChild.route.def.name} is not a session split child"),
    };

    return SessionSplitShell(
      projectId: projectId,
      projectName: projectName,
      selectedSessionId: selectedSessionId,
      routeKind: routeChild.routeKind,
      list: _SessionListPane(
        projectId: projectId,
        projectName: projectName,
        selectedSessionId: selectedSessionId,
        fullScreenChild: routeChild.child,
      ),
      detail: switch (routeChild.routeKind) {
        SessionSplitRouteKind.list => const EmptySessionDetailPanel(),
        SessionSplitRouteKind.detail || SessionSplitRouteKind.diffs => routeChild.child,
      },
    );
  }
}

class _SessionListPane extends StatelessWidget {
  final String projectId;
  final String? projectName;
  final String? selectedSessionId;
  final Widget fullScreenChild;

  const _SessionListPane({
    required this.projectId,
    required this.projectName,
    required this.selectedSessionId,
    required this.fullScreenChild,
  });

  @override
  Widget build(BuildContext context) {
    final scope = SessionSplitScope.of(context);
    if (!scope.isSplit) return fullScreenChild;
    const actionDispatcher = SessionListActionDispatcher();

    return KeyedSubtree(
      key: ValueKey("session-list-$projectId"),
      child: SessionListCubitProvider(
        projectId: projectId,
        child: SessionListPanel(
          projectName: projectName,
          selectedSessionId: selectedSessionId,
          onNewSession: () => context.pushRoute(AppRoute.newSession(projectId: projectId)),
          onSessionTap: (session) {
            context.goRoute(
              AppRoute.sessionDetail(
                projectId: projectId,
                sessionId: session.id,
                sessionTitle: session.title ?? "",
                readOnly: false,
              ),
            );
          },
          onSessionLongPress: (session) => actionDispatcher.showSessionActions(context: context, session: session),
          onSessionSwipe: (session) => actionDispatcher.handleSessionSwipe(context: context, session: session),
        ),
      ),
    );
  }
}
final appRouter = GoRouter(
  initialLocation: AppRouteDef.splash.path,
  onException: (context, state, router) {
    final uri = state.uri;
    if (uri.scheme == bundleId) return logd("GoRouter ignoring deep link (handled by app_links): $uri");
    loge("GoRouter could not match route: ${uri.toString()}");
  },
  routes: buildAppRoutes(),
);
