import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/widgets/session_split/empty_session_detail_panel.dart";
import "../../core/widgets/session_split/session_split_scope.dart";
import "../../core/widgets/session_split/session_split_shell.dart";
import "../../features/login/login_screen.dart";
import "../../features/new_session/new_session_screen.dart";
import "../../features/project_list/project_list_screen.dart";
import "../../features/session_detail/session_detail_screen.dart";
import "../../features/session_diffs/session_diffs_screen.dart";
import "../../features/session_list/session_list_action_dispatcher.dart";
import "../../features/session_list/session_list_cubit_provider.dart";
import "../../features/session_list/session_list_panel.dart";
import "../../features/session_list/session_list_screen.dart";
import "../../features/settings/notification_settings_screen.dart";
import "../../features/settings/plugin_settings_screen.dart";
import "../../features/settings/profile_screen.dart";
import "../../features/settings/settings_screen.dart";
import "../../features/splash/splash_screen.dart";
import "../extensions/build_context_x.dart";
import "../widgets/sesori_logo.dart";
import "imperative_pane_route.dart";

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _sessionShellNavigatorKey = GlobalKey<NavigatorState>();

const _newSessionRouteSegment = "new";
const _sessionsRouteSegment = ":$projectIdPathParam/sessions";
const _sessionDetailRouteSegment = ":$sessionIdPathParam";
const _sessionDiffsRouteSegment = "diffs";
const _settingsNotificationsRouteSegment = "notifications";
const _settingsPluginsRouteSegment = "plugins";
const _settingsProfileRouteSegment = "profile";

extension AppRouteToGoRoute on AppRouteDef {
  /// Returns the [GoRoute] for this route definition with an exhaustive
  /// builder switch over decoded [AppRoute] values.
  GoRoute toGoRoute({List<RouteBase> routes = const []}) {
    // The login screen gets a fade-in page instead of the platform slide so
    // the splash → login hand-off reads as one continuous motion — see
    // _loginTransitionPage.
    if (this == AppRouteDef.login) {
      return GoRoute(
        path: path,
        routes: routes,
        pageBuilder: (context, state) => _loginTransitionPage(
          context: context,
          state: state,
          child: _buildScreen(context: context, state: state),
        ),
      );
    }
    // Settings presents as a full-screen modal (slides up from the bottom on
    // iOS) closed via its X button rather than a back chevron.
    if (this == AppRouteDef.settings) {
      return GoRoute(
        path: path,
        routes: routes,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          fullscreenDialog: true,
          child: _buildScreen(context: context, state: state),
        ),
      );
    }
    return GoRoute(
      path: path,
      routes: routes,
      builder: (context, state) => _buildScreen(context: context, state: state),
    );
  }

  Widget _buildScreen({required BuildContext context, required GoRouterState state}) {
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
      AppRouteSettingsNotifications() => const NotificationSettingsScreen(),
      AppRouteSettingsPlugins() => const PluginSettingsScreen(),
      AppRouteSettingsProfile() => const ProfileScreen(),
      AppRouteSessions(:final projectId, :final projectName) => SessionListScreen(
        projectId: projectId,
        projectName: projectName,
      ),
      AppRouteNewSession(:final projectId, :final projectName) => NewSessionScreen(
        projectId: projectId,
        projectName: projectName,
        initialSupportsDedicatedWorktrees: null,
      ),
      AppRouteSessionDetail(
        :final projectId,
        :final projectName,
        :final sessionId,
        :final sessionTitle,
        :final readOnly,
      ) =>
        SessionDetailScreen(
          projectId: projectId,
          projectName: projectName,
          sessionId: sessionId,
          sessionTitle: sessionTitle,
          readOnly: readOnly,
        ),
      AppRouteSessionDiffs(:final projectId, :final sessionId) => SessionDiffsScreen(
        projectId: projectId,
        sessionId: sessionId,
      ),
    };
  }
}

Page<void> buildSessionPaneTransitionPage({
  required BuildContext context,
  required GoRouterState state,
  required LocalKey pageKey,
  required Widget child,
}) {
  final duration = context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 220);
  final isImperative = isImperativePaneState(context: context, state: state);
  return CustomTransitionPage<void>(
    key: pageKey,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final isSplit = SessionSplitScope.maybeOf(context)?.isSplit ?? false;
      if (isSplit) {
        return FadeTransition(
          opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
          child: child,
        );
      }
      final modalRoute = ModalRoute.of(context);
      if (modalRoute is! PageRoute<void>) {
        throw StateError("Session pane transitions require a PageRoute");
      }
      return Theme.of(context).pageTransitionsTheme.buildTransitions<void>(
        modalRoute,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    },
    child: ImperativePaneRouteScope(isImperative: isImperative, child: child),
  );
}

/// Fade-only page transition for every navigation into the login screen.
///
/// When coming from the splash screen, the splash stays visible underneath
/// while the login screen — which shares the same background — fades in on
/// top. The splash title appears to dissolve, the login text and buttons
/// fade in, and the [SesoriLogo] hero glides from the screen center to its
/// login position. Other entry points (logout, session expiry) get the same
/// fade without a hero flight.
Page<void> _loginTransitionPage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  // Reduced motion only zeroes the duration: returning a different Page
  // subclass here would fail Page.canUpdate and recreate the login route —
  // dropping in-flight login state — if the OS setting flips while the
  // screen is shown.
  final duration = context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 500);
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(
      opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
      child: child,
    ),
    child: child,
  );
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

  void replaceRoute(AppRoute route) {
    // ignore: no_slop_linter/avoid_raw_go_router, typed wrapper implementation
    GoRouter.of(this).replace<void>(route.buildPath());
  }
}

extension GoRouterNavigation on GoRouter {
  void goRoute(AppRoute route) {
    go(route.buildPath());
  }

  void replaceRoute(AppRoute route) {
    replace<void>(route.buildPath());
  }
}

List<RouteBase> buildAppRoutes() {
  return _buildAppRoutes(rootNavigatorKey: _rootNavigatorKey, sessionShellNavigatorKey: _sessionShellNavigatorKey);
}

List<RouteBase> buildAppRoutesForTesting({required GlobalKey<NavigatorState> rootNavigatorKey}) {
  return _buildAppRoutes(rootNavigatorKey: rootNavigatorKey, sessionShellNavigatorKey: GlobalKey<NavigatorState>());
}

List<RouteBase> _buildAppRoutes({
  required GlobalKey<NavigatorState> rootNavigatorKey,
  required GlobalKey<NavigatorState> sessionShellNavigatorKey,
}) {
  return [
    AppRouteDef.splash.toGoRoute(),
    AppRouteDef.login.toGoRoute(),
    AppRouteDef.projects.toGoRoute(
      routes: [
        ShellRoute(
          navigatorKey: sessionShellNavigatorKey,
          builder: (context, state, child) {
            final projectId = state.pathParameters[projectIdPathParam] ?? "";
            final projectName = state.uri.queryParameters[projectNameQueryParam];
            final supportsDedicatedWorktrees =
                switch (state.uri.queryParameters[supportsDedicatedWorktreesQueryParam]) {
                  "true" => true,
                  "false" => false,
                  _ => null,
                };
            final selectedSessionId = state.pathParameters[sessionIdPathParam];

            return SessionListCubitProvider(
              key: ValueKey("session-list-cubit-$projectId"),
              projectId: projectId,
              initialSupportsDedicatedWorktrees: supportsDedicatedWorktrees,
              child: SessionSplitShell(
                list: _SessionListPane(
                  projectId: projectId,
                  projectName: projectName,
                  selectedSessionId: selectedSessionId,
                ),
                child: child,
              ),
            );
          },
          routes: [
            GoRoute(
              path: _sessionsRouteSegment,
              pageBuilder: (context, state) => buildSessionPaneTransitionPage(
                context: context,
                state: state,
                pageKey: state.pageKey,
                child: Builder(
                  builder: (context) {
                    final route = switch (AppRoute.fromDef(
                      def: AppRouteDef.sessions,
                      pathParams: state.pathParameters,
                      queryParams: state.uri.queryParameters,
                    )) {
                      final AppRouteSessions route => route,
                      final route => throw StateError("Route ${route.def.name} is not a sessions route"),
                    };
                    return SessionSplitScope.of(context).isSplit
                        ? const EmptySessionDetailPanel()
                        : SessionListScreen(projectId: route.projectId, projectName: route.projectName);
                  },
                ),
              ),
              routes: [
                GoRoute(
                  path: _newSessionRouteSegment,
                  pageBuilder: (context, state) {
                    final route = switch (AppRoute.fromDef(
                      def: AppRouteDef.newSession,
                      pathParams: state.pathParameters,
                      queryParams: state.uri.queryParameters,
                    )) {
                      final AppRouteNewSession route => route,
                      final route => throw StateError("Route ${route.def.name} is not a new-session route"),
                    };
                    return buildSessionPaneTransitionPage(
                      context: context,
                      state: state,
                      pageKey: state.pageKey,
                      child: NewSessionScreen(
                        projectId: route.projectId,
                        projectName: route.projectName,
                        initialSupportsDedicatedWorktrees: context
                            .read<SessionListCubit>()
                            .initialSupportsDedicatedWorktrees,
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: _sessionDetailRouteSegment,
                  pageBuilder: (context, state) {
                    final route = switch (AppRoute.fromDef(
                      def: AppRouteDef.sessionDetail,
                      pathParams: state.pathParameters,
                      queryParams: state.uri.queryParameters,
                    )) {
                      final AppRouteSessionDetail route => route,
                      final route => throw StateError("Route ${route.def.name} is not a session-detail route"),
                    };
                    return buildSessionPaneTransitionPage(
                      context: context,
                      state: state,
                      pageKey: ValueKey((state.pageKey, route.projectId, route.sessionId)),
                      child: SessionDetailScreen(
                        key: ValueKey("session-detail-${route.sessionId}"),
                        projectId: route.projectId,
                        projectName: route.projectName,
                        sessionId: route.sessionId,
                        sessionTitle: route.sessionTitle,
                        readOnly: route.readOnly,
                      ),
                    );
                  },
                  routes: [
                    GoRoute(
                      path: _sessionDiffsRouteSegment,
                      pageBuilder: (context, state) {
                        final route = switch (AppRoute.fromDef(
                          def: AppRouteDef.sessionDiffs,
                          pathParams: state.pathParameters,
                          queryParams: state.uri.queryParameters,
                        )) {
                          final AppRouteSessionDiffs route => route,
                          final route => throw StateError("Route ${route.def.name} is not a session-diffs route"),
                        };
                        return buildSessionPaneTransitionPage(
                          context: context,
                          state: state,
                          pageKey: state.pageKey,
                          child: SessionDiffsScreen(
                            key: ValueKey("session-diffs-${route.sessionId}"),
                            projectId: route.projectId,
                            sessionId: route.sessionId,
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
    AppRouteDef.settings.toGoRoute(
      routes: [
        GoRoute(
          path: _settingsNotificationsRouteSegment,
          builder: (context, state) => AppRouteDef.settingsNotifications._buildScreen(context: context, state: state),
        ),
        GoRoute(
          path: _settingsPluginsRouteSegment,
          builder: (context, state) => AppRouteDef.settingsPlugins._buildScreen(context: context, state: state),
        ),
        GoRoute(
          path: _settingsProfileRouteSegment,
          builder: (context, state) => AppRouteDef.settingsProfile._buildScreen(context: context, state: state),
        ),
      ],
    ),
  ];
}

class _SessionListPane extends StatelessWidget {
  final String projectId;
  final String? projectName;
  final String? selectedSessionId;

  const _SessionListPane({
    required this.projectId,
    required this.projectName,
    required this.selectedSessionId,
  });

  @override
  Widget build(BuildContext context) {
    const actionDispatcher = SessionListActionDispatcher();
    // ignore: no_slop_linter/avoid_navigator_of, root navigator pop is required here so shell chrome exits the whole shell instead of the nested pane route
    final rootNavigator = Navigator.of(context);

    return KeyedSubtree(
      key: ValueKey("session-list-$projectId"),
      child: SessionListPanel(
        projectName: projectName,
        selectedSessionId: selectedSessionId,
        // Use the root navigator from shell chrome; GoRouter pop would target
        // the nested pane navigator and only pop the right-pane route.
        // ignore: unnecessary_lambdas, Navigator.pop is generic and does not match VoidCallback as a tear-off
        onBack: rootNavigator.canPop() ? () => rootNavigator.pop() : null,
        onNewSession: () => context.pushRoute(AppRoute.newSession(projectId: projectId, projectName: projectName)),
        onSessionTap: (session) {
          context.goRoute(
            AppRoute.sessionDetail(
              projectId: projectId,
              projectName: projectName,
              sessionId: session.id,
              sessionTitle: session.title ?? "",
              readOnly: false,
            ),
          );
        },
        sessionMenuEntries: (BuildContext context, Session session) =>
            actionDispatcher.sessionMenuEntries(context: context, session: session),
      ),
    );
  }
}

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRouteDef.splash.path,
  onException: (context, state, router) {
    final uri = state.uri;
    if (uri.scheme == bundleId) return logd("GoRouter ignoring deep link (handled by app_links): $uri");
    loge("GoRouter could not match route: ${uri.toString()}");
  },
  routes: buildAppRoutes(),
);
