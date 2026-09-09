import "package:cupertino_ui/cupertino_ui.dart" show CupertinoPage;
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../features/login/login_screen.dart";
import "../../features/new_session/new_session_screen.dart";
import "../../features/project_list/project_list_screen.dart";
import "../../features/session_detail/session_detail_screen.dart";
import "../../features/session_diffs/session_diffs_screen.dart";
import "../../features/session_list/archived_sessions_artwork.dart";
import "../../features/session_list/session_list_cubit_provider.dart";
import "../../features/session_list/session_list_screen.dart";
import "../../features/settings/default_input_settings_screen.dart";
import "../../features/settings/harnesses_settings_screen.dart";
import "../../features/settings/notification_settings_screen.dart";
import "../../features/settings/profile_screen.dart";
import "../../features/settings/settings_screen.dart";
import "../../features/splash/splash_screen.dart";
import "../di/injection.dart";
import "../widgets/sesori_background_widget.dart";
import "../widgets/sesori_logo.dart";
import "imperative_pane_route.dart";

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _sessionShellNavigatorKey = GlobalKey<NavigatorState>();

/// The root navigator hosting every app route. Used to present app-wide UI
/// (for example backend toast guidance) without a screen context.
GlobalKey<NavigatorState> get appRootNavigatorKey => _rootNavigatorKey;

const _newSessionRouteSegment = "new";
const _sessionsRouteSegment = ":$projectIdPathParam/sessions";
const _sessionDetailRouteSegment = ":$sessionIdPathParam";
const _sessionDiffsRouteSegment = "diffs";
const _settingsDefaultInputRouteSegment = "default-input";
const _settingsNotificationsRouteSegment = "notifications";
const _settingsProfileRouteSegment = "profile";

extension AppRouteToGoRoute on AppRouteDef {
  /// Returns the [GoRoute] for this route definition with an exhaustive
  /// screen switch over decoded [AppRoute] values.
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
    // Settings presents as a full-screen modal that slides up from the bottom
    // and is closed via its X button rather than a back chevron.
    //
    // A CupertinoPage — not a MaterialPage — because only the Cupertino route
    // honours `fullscreenDialog` with the bottom-up slide. Android's default
    // page transition ignores the flag, so a MaterialPage would push settings
    // in sideways like any other screen. CupertinoPageRoute ignores the
    // platform, giving both surfaces the same modal motion.
    if (this == AppRouteDef.settings) {
      return GoRoute(
        path: path,
        routes: routes,
        pageBuilder: (context, state) => CupertinoPage<void>(
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
    return AppRoute.fromDef(
      def: this,
      pathParams: state.pathParameters,
      queryParams: state.uri.queryParameters,
    ).screen;
  }
}

extension on AppRoute {
  /// The screen this decoded route shows. Separate from [AppRouteToGoRoute._buildScreen]
  /// so a page builder that already resolved its route — to choose a page type
  /// from the route's own parameters — builds the screen from that same
  /// instance instead of decoding the URL a second time.
  Widget get screen {
    return switch (this) {
      AppRouteArchivedSessions() ||
      AppRouteArchivedSessionDetail() => throw StateError("Archive pages belong to their flow shell"),
      AppRouteSplash() => const SplashScreen(),
      AppRouteLogin() => const LoginScreen(),
      AppRouteProjects() => const ProjectListScreen(),
      AppRouteSettings() => const SettingsScreen(),
      AppRouteSettingsDefaultInput() => const DefaultInputSettingsScreen(),
      AppRouteSettingsNotifications() => const NotificationSettingsScreen(),
      AppRouteSettingsHarnesses() ||
      AppRouteSettingsHarnessDetail() => throw StateError("Harness pages belong to their flow shell"),
      AppRouteSettingsProfile() => const ProfileScreen(),
      AppRouteSessions(:final projectId, :final projectName) => SessionListScreen(
        projectId: projectId,
        projectName: projectName,
      ),
      AppRouteNewSession(:final projectId, :final projectName) => NewSessionScreen(
        projectId: projectId,
        projectName: projectName,
      ),
      AppRouteSessionDetail(
        :final projectId,
        :final projectName,
        :final sessionId,
        :final sessionTitle,
        :final readOnly,
      ) =>
        SessionDetailScreen(
          auditView: false,
          onBack: null,
          onClose: null,
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
            final selectedSessionId = state.pathParameters[sessionIdPathParam];
            final projectViewingService = getIt<ProjectViewingService>();

            return SessionListCubitProvider(
              filter: SessionListFilter.active,
              key: ValueKey("session-list-cubit-$projectId"),
              projectId: projectId,
              child: SessionSplitShell(
                projectViewingService: projectViewingService,
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
                        ? EmptySessionDetailPanel(
                            background: const SesoriBackgroundWidget(),
                            connectionBanner: ConnectionBanner.maybeFor(context),
                          )
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
                        auditView: false,
                        onBack: null,
                        onClose: null,
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
    buildArchivedSessionsRoute(),
    buildHarnessSettingsRoute(),
    AppRouteDef.settings.toGoRoute(
      routes: [
        GoRoute(
          path: _settingsDefaultInputRouteSegment,
          builder: (context, state) => AppRouteDef.settingsDefaultInput._buildScreen(context: context, state: state),
        ),
        GoRoute(
          path: _settingsNotificationsRouteSegment,
          builder: (context, state) => AppRouteDef.settingsNotifications._buildScreen(context: context, state: state),
        ),
        GoRoute(
          path: _settingsProfileRouteSegment,
          builder: (context, state) => AppRouteDef.settingsProfile._buildScreen(context: context, state: state),
        ),
      ],
    ),
  ];
}

class const _SessionListPane({
  required final String projectId,
  required final String? projectName,
  required final String? selectedSessionId,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const actionDispatcher = SessionListActionDispatcher(onSessionDeleted: closeDeletedSessionRoute);
    // ignore: no_slop_linter/avoid_navigator_of, root navigator pop is required here so shell chrome exits the whole shell instead of the nested pane route
    final rootNavigator = Navigator.of(context);

    return KeyedSubtree(
      key: ValueKey("session-list-$projectId"),
      child: SessionListPanel(
        onOpenArchived: () =>
            context.pushRoute(AppRoute.archivedSessions(projectId: projectId, projectName: projectName)),
        projectName: projectName,
        selectedSessionId: selectedSessionId,
        // Use the root navigator from shell chrome; GoRouter pop would target
        // the nested pane navigator and only pop the right-pane route.
        // ignore: unnecessary_lambdas, Navigator.pop is generic and does not match VoidCallback as a tear-off
        onBack: rootNavigator.canPop() ? () => rootNavigator.pop() : null,
        onNewSession: () => context.pushRoute(AppRoute.newSession(projectId: projectId, projectName: projectName)),
        onSessionTap: ({required session}) {
          context.goRoute(
            AppRoute.sessionDetail(
              projectId: projectId,
              projectName: projectName,
              sessionId: session.id,
              sessionTitle: session.title,
              readOnly: false,
            ),
          );
        },
        actionDispatcher: actionDispatcher,
        archivedEmptyState: const SessionArchivedEmptyState(artwork: ArchivedSessionsArtwork()),
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

/// Harness-only navigator and provider shared by overview and URL detail pages.
@visibleForTesting
ShellRoute buildHarnessSettingsRoute() {
  final navigatorKey = GlobalKey<NavigatorState>();
  void close({required BuildContext context}) {
    // The nested Navigator's context belongs to the stable outer flow page.
    final flowContext = navigatorKey.currentContext ?? (throw StateError("Harness flow is not mounted"));
    final flowRoute = ModalRoute.of(flowContext) ?? (throw StateError("Harness flow has no owning route"));
    final outerNavigator = flowRoute.navigator ?? (throw StateError("Harness flow has no navigator"));
    // Remove owned pageless sheets first, without touching the opener.
    outerNavigator.popUntil((route) => route == flowRoute);
    if (flowRoute.isFirst) {
      context.goRoute(const AppRoute.projects());
    } else {
      outerNavigator.pop();
    }
  }

  return ShellRoute(
    navigatorKey: navigatorKey,
    pageBuilder: (context, state, child) {
      final presentation = AppRouteSettingsHarnesses.fromParams(queryParams: state.uri.queryParameters).presentation;
      final content = HarnessesSettingsScreen(child: child);
      return presentation == HarnessSettingsPresentation.modal
          ? CupertinoPage<void>(key: state.pageKey, fullscreenDialog: true, child: content)
          : MaterialPage<void>(key: state.pageKey, child: content);
    },
    routes: [
      GoRoute(
        path: AppRouteDef.settingsHarnesses.path,
        builder: (context, state) {
          final presentation = AppRouteSettingsHarnesses.fromParams(queryParams: state.uri.queryParameters)
              .presentation;
          return HarnessesSettingsView(
            presentation: presentation,
            connectionBanner: ConnectionBanner.maybeFor(context),
            onClose: () => close(context: context),
            onBack: () => close(context: context),
            onOpenHarness: ({required pluginId}) => context.pushRoute(
              AppRoute.settingsHarnessDetail(pluginId: pluginId, presentation: presentation),
            ),
          );
        },
        routes: [
          GoRoute(
            path: ":$pluginIdPathParam",
            builder: (context, state) {
              final route = AppRouteSettingsHarnessDetail.fromParams(
                pathParams: state.pathParameters,
                queryParams: state.uri.queryParameters,
              );
              return HarnessSettingsDetailView(
                pluginId: route.pluginId,
                presentation: route.presentation,
                connectionBanner: ConnectionBanner.maybeFor(context),
                onBack: () => context.pop(),
                onClose: () => close(context: context),
              );
            },
          ),
        ],
      ),
    ],
  );
}

/// A full-screen audit flow outside the adaptive live-session panes.
@visibleForTesting
ShellRoute buildArchivedSessionsRoute() {
  final navigatorKey = GlobalKey<NavigatorState>();
  void close({required BuildContext context}) {
    final flowContext = navigatorKey.currentContext ?? (throw StateError("Archive flow is not mounted"));
    final flowRoute = ModalRoute.of(flowContext) ?? (throw StateError("Archive flow has no owning route"));
    final outerNavigator = flowRoute.navigator ?? (throw StateError("Archive flow has no navigator"));
    outerNavigator.popUntil((route) => route == flowRoute);
    if (flowRoute.isFirst) {
      context.goRoute(const AppRoute.projects());
    } else {
      outerNavigator.pop();
    }
  }

  return ShellRoute(
    navigatorKey: navigatorKey,
    pageBuilder: (context, state, child) => CupertinoPage<void>(
      key: state.pageKey,
      fullscreenDialog: true,
      child: SessionListCubitProvider(
        key: ValueKey("archive-list-${state.pathParameters[projectIdPathParam]}"),
        projectId:
            state.pathParameters[projectIdPathParam] ?? (throw StateError("Archive flow requires project identity")),
        filter: SessionListFilter.archived,
        child: child,
      ),
    ),
    routes: [
      GoRoute(
        path: AppRouteDef.archivedSessions.path,
        builder: (context, state) {
          final route = AppRouteArchivedSessions.fromParams(
            pathParams: state.pathParameters,
            queryParams: state.uri.queryParameters,
          );
          return ArchivedSessionsView(
            emptyState: const SessionArchivedEmptyState(artwork: ArchivedSessionsArtwork()),
            onClose: () => close(context: context),
            onSessionTap: ({required session}) => context.pushRoute(
              AppRoute.archivedSessionDetail(
                projectId: route.projectId,
                projectName: route.projectName,
                sessionId: session.id,
                sessionTitle: session.title,
              ),
            ),
            actionDispatcher: SessionListActionDispatcher(
              onSessionDeleted: ({required context, required sessionId}) =>
                  closeDeletedArchivedSessionRoute(context: context, projectId: route.projectId, sessionId: sessionId),
            ),
          );
        },
        routes: [
          GoRoute(
            path: ":$sessionIdPathParam",
            builder: (context, state) {
              final route = AppRouteArchivedSessionDetail.fromParams(
                pathParams: state.pathParameters,
                queryParams: state.uri.queryParameters,
              );
              return SessionDetailScreen(
                key: ValueKey("archived-detail-${route.sessionId}"),
                projectId: route.projectId,
                projectName: route.projectName,
                sessionId: route.sessionId,
                sessionTitle: route.sessionTitle,
                readOnly: true,
                auditView: true,
                onBack: context.pop,
                onClose: () => close(context: context),
              );
            },
          ),
        ],
      ),
    ],
  );
}

/// A stale deletion must not move a different audit record or the live opener.
void closeDeletedArchivedSessionRoute({
  required BuildContext context,
  required String projectId,
  required String sessionId,
}) {
  // ignore: no_slop_linter/avoid_raw_go_router, current location identity check before typed navigation
  final state = GoRouter.of(context).state;
  if (state.fullPath != AppRouteDef.archivedSessionDetail.path) return;
  final route = AppRouteArchivedSessionDetail.fromParams(
    pathParams: state.pathParameters,
    queryParams: state.uri.queryParameters,
  );
  if (route.projectId != projectId || route.sessionId != sessionId) return;
  // Pop only the archive navigator; go() would discard the modal's opener.
  // ignore: no_slop_linter/avoid_navigator_of, pop owned audit pages without replacing the root stack
  Navigator.of(context).popUntil((route) => route.isFirst);
}
