import "dart:async";

import "package:firebase_analytics/firebase_analytics.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/firebase_analytics_client.dart";
import "package:sesori_mobile/core/platform/go_router_route_source.dart";

/// Records every call the client hands to the Firebase SDK, in order, so the
/// test can assert the exact reporting payload a navigation flow produces.
class _RecordingFirebaseAnalytics() extends Fake implements FirebaseAnalytics {
  final order = <String>[];
  final eventScreens = <String?>[];
  final screenViews = <({String? screenName, String? screenClass})>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    List<AnalyticsEventItem>? items,
    AnalyticsCallOptions? callOptions,
  }) async {
    order.add("event:$name");
    eventScreens.add(parameters?["screen"] as String?);
  }

  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    order.add("screenView:$screenName");
    screenViews.add((screenName: screenName, screenClass: screenClass));
  }
}

/// Stands in for the preference-gated service and delivers straight into the
/// production Firebase client, so the test exercises the real reporting seam.
class _AlwaysActiveProductAnalyticsService({required FirebaseAnalyticsClient analyticsClient})
    extends Fake
    implements ProductAnalyticsService {
  final FirebaseAnalyticsClient _analyticsClient = analyticsClient;
  final BehaviorSubject<ProductAnalyticsState> _states = BehaviorSubject.seeded(_activeState());

  @override
  ValueStream<ProductAnalyticsState> get stateStream => _states.stream;

  @override
  ProductAnalyticsState get state => _states.value;

  @override
  Future<void> markPostSplashReady() async {}

  @override
  Future<AnalyticsDeliveryResult> logEvent({
    required ProductAnalyticsEvent event,
    required DateTime occurredAtUtc,
  }) async {
    await _analyticsClient.logProductEvent(
      envelope: ProductAnalyticsEnvelope(event: event, occurredAtUtc: occurredAtUtc),
      userKey: _serverDerivedUserKey,
    );
    return AnalyticsDeliveryResult.acceptedBySdk;
  }

  /// Publishes a state before the listener subscribes, replacing the seeded
  /// active one for tests that begin with analytics inactive.
  void seedInactive() => _states.add(_inactiveState());

  void activate() => _states.add(_activeState());

  Future<void> disposeFake() => _states.close();
}

/// Mirrors the production route tree's shape — the session routes nested under
/// a [ShellRoute] and the settings subroutes — with placeholder screens, so
/// navigation needs no DI.
GoRouter _router() {
  return GoRouter(
    initialLocation: AppRouteDef.splash.path,
    routes: [
      GoRoute(path: AppRouteDef.splash.path, builder: (_, _) => const Text("splash")),
      GoRoute(path: AppRouteDef.login.path, builder: (_, _) => const Text("login")),
      GoRoute(
        path: AppRouteDef.projects.path,
        builder: (_, _) => const Text("projects"),
        routes: [
          ShellRoute(
            builder: (_, _, child) => child,
            routes: [
              GoRoute(
                path: ":$projectIdPathParam/sessions",
                builder: (_, _) => const Text("sessions"),
                routes: [
                  GoRoute(path: "new", builder: (_, _) => const Text("new session")),
                  GoRoute(
                    path: ":$sessionIdPathParam",
                    builder: (_, _) => const Text("session detail"),
                    routes: [GoRoute(path: "diffs", builder: (_, _) => const Text("session diffs"))],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRouteDef.settings.path,
        builder: (_, _) => const Text("settings"),
        routes: [
          GoRoute(path: "notifications", builder: (_, _) => const Text("notification settings")),
          GoRoute(path: "harnesses", builder: (_, _) => const Text("harness settings")),
          GoRoute(path: "profile", builder: (_, _) => const Text("profile")),
        ],
      ),
    ],
  );
}

ProductAnalyticsState _activeState() => const ProductAnalyticsState(
  preference: ProductAnalyticsPreferenceUnknown(),
  synchronization: ProductAnalyticsSynchronized(),
  availability: ProductAnalyticsActive(),
);

ProductAnalyticsState _inactiveState() => const ProductAnalyticsState(
  preference: ProductAnalyticsPreferenceUnknown(),
  synchronization: ProductAnalyticsNotSynchronized(),
  availability: ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.preferenceUnknown),
);

const _serverDerivedUserKey = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

Future<void> _flush(WidgetTester tester) async {
  // Real timers never fire in the widget test's fake-async zone without a
  // pump; two pumps let the listener's delivery chain settle.
  await tester.pump();
  await tester.pump();
}

void main() {
  late GoRouter router;
  late GoRouterRouteSource routeSource;
  late _RecordingFirebaseAnalytics analytics;
  late FirebaseAnalyticsClient analyticsClient;
  late _AlwaysActiveProductAnalyticsService analyticsService;
  late AnalyticsRouteListener listener;

  setUp(() {
    router = _router();
    routeSource = GoRouterRouteSource.test(router: router);
    analytics = _RecordingFirebaseAnalytics();
    analyticsClient = FirebaseAnalyticsClient(
      analytics: analytics,
      capability: const AnalyticsRuntimeCapability.enabled(),
    );
    analyticsService = _AlwaysActiveProductAnalyticsService(analyticsClient: analyticsClient);
    listener = AnalyticsRouteListener(routeSource: routeSource, analyticsService: analyticsService);
  });

  tearDown(() async {
    await listener.dispose();
    await routeSource.onDispose();
    await analyticsService.disposeFake();
    router.dispose();
  });

  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await listener.start();
    await _flush(tester);
  }

  testWidgets("reports every screen of a realistic navigation flow to Firebase with its pinned identity", (
    tester,
  ) async {
    await pumpRouter(tester);

    // Splash is a readiness route and must never be reported.
    expect(analytics.order, isEmpty);

    router.go(const AppRoute.login().buildPath());
    await tester.pumpAndSettle();
    await _flush(tester);

    router.go(const AppRoute.projects().buildPath());
    await tester.pumpAndSettle();
    await _flush(tester);

    // Settings opens as a pushed full-screen modal from the project list.
    unawaited(router.push<void>(const AppRoute.settings().buildPath()));
    await tester.pumpAndSettle();
    await _flush(tester);

    unawaited(router.push<void>(const AppRoute.settingsProfile().buildPath()));
    await tester.pumpAndSettle();
    await _flush(tester);

    router.pop<void>();
    await tester.pumpAndSettle();
    await _flush(tester);

    router.go(const AppRoute.sessions(projectId: "p1", projectName: null).buildPath());
    await tester.pumpAndSettle();
    await _flush(tester);

    unawaited(router.push<void>(const AppRoute.newSession(projectId: "p1", projectName: null).buildPath()));
    await tester.pumpAndSettle();
    await _flush(tester);

    router.pop<void>();
    await tester.pumpAndSettle();
    await _flush(tester);

    router.go(
      const AppRoute.sessionDetail(
        projectId: "p1",
        projectName: null,
        sessionId: "s1",
        sessionTitle: null,
        readOnly: false,
      ).buildPath(),
    );
    await tester.pumpAndSettle();
    await _flush(tester);

    unawaited(
      router.push<void>(const AppRoute.sessionDiffs(projectId: "p1", projectName: null, sessionId: "s1").buildPath()),
    );
    await tester.pumpAndSettle();
    await _flush(tester);

    router.pop<void>();
    await tester.pumpAndSettle();
    await _flush(tester);

    const reportedScreens = [
      AnalyticsScreen.login,
      AnalyticsScreen.projects,
      AnalyticsScreen.settings,
      AnalyticsScreen.settingsProfile,
      AnalyticsScreen.settings,
      AnalyticsScreen.sessions,
      AnalyticsScreen.newSession,
      AnalyticsScreen.sessions,
      AnalyticsScreen.sessionDetail,
      AnalyticsScreen.sessionDiffs,
      AnalyticsScreen.sessionDetail,
    ];

    expect(
      analytics.order,
      [
        for (final screen in reportedScreens) ...["event:product_screen_viewed", "screenView:${screen.wireValue}"],
      ],
    );
    expect(analytics.eventScreens, [for (final screen in reportedScreens) screen.wireValue]);
    expect(
      analytics.screenViews,
      [
        for (final screen in reportedScreens) (screenName: screen.wireValue, screenClass: screen.wireValue),
      ],
    );
  });

  testWidgets("holds screens back while analytics is inactive and reports the current one on activation", (
    tester,
  ) async {
    analyticsService = _AlwaysActiveProductAnalyticsService(analyticsClient: analyticsClient);
    analyticsService.seedInactive();
    listener = AnalyticsRouteListener(routeSource: routeSource, analyticsService: analyticsService);

    await pumpRouter(tester);

    router.go(const AppRoute.projects().buildPath());
    await tester.pumpAndSettle();
    await _flush(tester);
    expect(analytics.order, isEmpty);

    analyticsService.activate();
    await _flush(tester);

    expect(analytics.order, ["event:product_screen_viewed", "screenView:projects"]);
    expect(
      analytics.screenViews.single,
      (screenName: "projects", screenClass: "projects"),
    );
  });
}
