import "dart:async";

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";

import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../logging/logging.dart";
import "../platform/route_source.dart";
import "../repositories/models/analytics_delivery_result.dart";
import "../services/models/product_analytics_state.dart";
import "../services/product_analytics_service.dart";
import "app_routes.dart";

const _screenDeliveryDeadline = Duration(seconds: 10);

@lazySingleton
class AnalyticsRouteListener {
  final RouteSource _routeSource;
  final ProductAnalyticsService _analyticsService;
  final Duration _deliveryDeadline;
  StreamSubscription<AppRouteDef?>? _routeSubscription;
  StreamSubscription<ProductAnalyticsState>? _stateSubscription;
  AnalyticsScreen? _currentScreen;
  DateTime? _currentScreenOccurredAtUtc;
  AnalyticsScreen? _reportedScreen;
  final Set<AnalyticsScreen> _inFlightScreens = {};
  final Set<AnalyticsScreen> _reportAgainScreens = {};
  bool _started = false;

  new({required RouteSource routeSource, required ProductAnalyticsService analyticsService})
    : _routeSource = routeSource,
      _analyticsService = analyticsService,
      _deliveryDeadline = _screenDeliveryDeadline;

  @visibleForTesting
  new withDeliveryDeadline({
    required RouteSource routeSource,
    required ProductAnalyticsService analyticsService,
    required Duration deliveryDeadline,
  }) : _routeSource = routeSource,
       _analyticsService = analyticsService,
       _deliveryDeadline = deliveryDeadline;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _routeSubscription = _routeSource.currentRouteStream.listen((route) {
      unawaited(
        _onRoute(route: route).catchError((Object error, StackTrace stackTrace) {
          logw("Failed to process analytics route", error, stackTrace);
        }),
      );
    });
    _stateSubscription = _analyticsService.stateStream.listen((state) {
      if (state.availability is ProductAnalyticsActive) {
        unawaited(
          _reportCurrentScreen().catchError((Object error, StackTrace stackTrace) {
            logw("Failed to report analytics screen", error, stackTrace);
          }),
        );
      }
    });
  }

  Future<void> _onRoute({required AppRouteDef? route}) async {
    if (route == null || route == AppRouteDef.splash) {
      _currentScreen = null;
      _currentScreenOccurredAtUtc = null;
      _reportedScreen = null;
      return;
    }
    final screen = _screenFor(route: route);
    if (screen != _currentScreen) _reportedScreen = null;
    _currentScreen = screen;
    _currentScreenOccurredAtUtc = DateTime.now().toUtc();
    await _analyticsService.markPostSplashReady();
    await _reportCurrentScreen();
  }

  Future<void> _reportCurrentScreen() async {
    final screen = _currentScreen;
    final occurredAtUtc = _currentScreenOccurredAtUtc;
    if (screen == null || occurredAtUtc == null || screen == _reportedScreen || !_analyticsService.state.isActive) {
      return;
    }
    if (_inFlightScreens.contains(screen)) {
      _reportAgainScreens.add(screen);
      return;
    }
    _inFlightScreens.add(screen);
    try {
      final result = await _analyticsService
          .logEvent(
            event: ProductAnalyticsEvent.screenViewed(screen: screen),
            occurredAtUtc: occurredAtUtc,
          )
          .timeout(_deliveryDeadline, onTimeout: () => AnalyticsDeliveryResult.failed);
      if (result == AnalyticsDeliveryResult.acceptedBySdk && screen == _currentScreen) {
        _reportedScreen = screen;
      } else if (result == AnalyticsDeliveryResult.failed &&
          screen == _currentScreen &&
          _analyticsService.state.isActive) {
        logw("Failed to deliver analytics screen event");
      }
    } finally {
      _inFlightScreens.remove(screen);
      if (_reportAgainScreens.remove(screen)) {
        await _reportCurrentScreen();
      }
    }
  }

  AnalyticsScreen _screenFor({required AppRouteDef route}) => switch (route) {
    AppRouteDef.splash => throw StateError("Splash is a readiness route, not an analytics screen"),
    AppRouteDef.login => AnalyticsScreen.login,
    AppRouteDef.projects => AnalyticsScreen.projects,
    AppRouteDef.settings || AppRouteDef.settingsHarnesses => AnalyticsScreen.settings,
    AppRouteDef.settingsNotifications => AnalyticsScreen.settingsNotifications,
    AppRouteDef.settingsProfile => AnalyticsScreen.settingsProfile,
    AppRouteDef.sessions => AnalyticsScreen.sessions,
    AppRouteDef.newSession => AnalyticsScreen.newSession,
    AppRouteDef.sessionDetail => AnalyticsScreen.sessionDetail,
    AppRouteDef.sessionDiffs => AnalyticsScreen.sessionDiffs,
  };

  @disposeMethod
  Future<void> dispose() async {
    await _routeSubscription?.cancel();
    await _stateSubscription?.cancel();
    _routeSubscription = null;
    _stateSubscription = null;
  }
}
