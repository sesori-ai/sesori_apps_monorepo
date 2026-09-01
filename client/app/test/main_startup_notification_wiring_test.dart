import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/analytics_runtime_bootstrap.dart";
import "package:sesori_mobile/main.dart";

class MockLocalNotificationClient() extends Mock implements LocalNotificationClient;

class MockPushMessagingSource() extends Mock implements PushMessagingSource;

class MockNotificationRegistrationService() extends Mock implements NotificationRegistrationService;

class MockForegroundNotificationDispatcher() extends Mock implements ForegroundNotificationDispatcher;

class MockNotificationOpenDispatcher() extends Mock implements NotificationOpenDispatcher;

void main() {
  test("notification and UI startup do not await the analytics crawl gate", () async {
    final events = <String>[];
    final crawlGate = Completer<AnalyticsStoreCrawlGate>();
    final singularGateApplied = Completer<void>();
    final startupStarted = Completer<void>();
    final allowStartupFinish = Completer<void>();

    Future<AnalyticsRuntimeBootstrap> configureDependencies() async {
      events.add("configureDependencies");
      return AnalyticsRuntimeBootstrap(
        capability: const AnalyticsRuntimeCapability.enabled(),
        crawlGate: crawlGate.future,
      );
    }

    void prepareSingularAttribution() => events.add("singularAttribution.prepare");

    void applySingularCrawlGate({required AnalyticsStoreCrawlGate crawlGate}) {
      events.add("singularAttribution.${crawlGate.name}");
      singularGateApplied.complete();
    }

    void initializeDeepLinks() => events.add("deepLinks");

    Future<void> startAttribution() async => events.add("attribution");

    Future<void> startProductAnalytics() async => events.add("productAnalytics");

    Future<void> startAnalyticsRouteListener() async => events.add("analyticsRoutes");

    Future<void> startNotificationStartup() async {
      events.add("notificationStartup.start");
      startupStarted.complete();
      await allowStartupFinish.future;
      events.add("notificationStartup.done");
    }

    Future<AppearanceMode> readAppearance() async {
      events.add("readAppearance");
      return AppearanceMode.dark;
    }

    Future<ChatInputMode> readChatInputMode() async {
      events.add("readChatInputMode");
      return ChatInputMode.voiceFirst;
    }

    void runAppFn(_) => events.add("runApp");

    await bootstrapSesoriApp(
      shouldInitializeFirebase: true,
      configureDependenciesFn: configureDependencies,
      prepareSingularAttributionFn: prepareSingularAttribution,
      applySingularCrawlGateFn: applySingularCrawlGate,
      initializeDeepLinks: initializeDeepLinks,
      startAttributionFn: startAttribution,
      startProductAnalyticsFn: startProductAnalytics,
      startAnalyticsRouteListenerFn: startAnalyticsRouteListener,
      startNotificationStartupFn: startNotificationStartup,
      readAppearanceFn: readAppearance,
      readChatInputModeFn: readChatInputMode,
      runAppFn: runAppFn,
    );

    await startupStarted.future.timeout(const Duration(seconds: 2));

    expect(events, [
      "configureDependencies",
      "singularAttribution.prepare",
      "deepLinks",
      "productAnalytics",
      "analyticsRoutes",
      "notificationStartup.start",
      // The persisted preferences are restored before the first frame, so the
      // app never launches in the wrong appearance.
      "readAppearance",
      "readChatInputMode",
      "runApp",
    ]);

    crawlGate.complete(AnalyticsStoreCrawlGate.suspend);
    await singularGateApplied.future.timeout(const Duration(seconds: 2));
    allowStartupFinish.complete();
    await Future<void>.delayed(Duration.zero);

    expect(
      events,
      [
        "configureDependencies",
        "singularAttribution.prepare",
        "deepLinks",
        "productAnalytics",
        "analyticsRoutes",
        "notificationStartup.start",
        "readAppearance",
        "readChatInputMode",
        "runApp",
        "singularAttribution.suspend",
        "attribution",
        "notificationStartup.done",
      ],
    );
  });

  test("Singular gate application failure does not block app bootstrap", () async {
    final events = <String>[];
    final singularGateAttempted = Completer<void>();

    await bootstrapSesoriApp(
      shouldInitializeFirebase: false,
      configureDependenciesFn: () async {
        events.add("configureDependencies");
        return AnalyticsRuntimeBootstrap(
          capability: const AnalyticsRuntimeCapability.disabled(
            reason: AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
          ),
          crawlGate: Future.value(AnalyticsStoreCrawlGate.allow),
        );
      },
      prepareSingularAttributionFn: () => events.add("singularAttribution.prepare"),
      applySingularCrawlGateFn: ({required crawlGate}) {
        events.add("singularAttribution.${crawlGate.name}");
        singularGateAttempted.complete();
        throw StateError("startup failed");
      },
      initializeDeepLinks: () => events.add("deepLinks"),
      startAttributionFn: () async => events.add("attribution"),
      startProductAnalyticsFn: () async => events.add("productAnalytics"),
      startAnalyticsRouteListenerFn: () async => events.add("analyticsRoutes"),
      startNotificationStartupFn: () async => events.add("notificationStartup"),
      readAppearanceFn: () async => AppearanceMode.system,
      readChatInputModeFn: () async => ChatInputMode.textFirst,
      runAppFn: (_) => events.add("runApp"),
    );
    await singularGateAttempted.future.timeout(const Duration(seconds: 2));

    expect(events, [
      "configureDependencies",
      "singularAttribution.prepare",
      "deepLinks",
      "productAnalytics",
      "analyticsRoutes",
      "runApp",
      "singularAttribution.allow",
    ]);
  });

  test("notification startup initializes adapters before starting dispatchers", () async {
    final events = <String>[];
    final localNotificationClient = MockLocalNotificationClient();
    final pushMessagingSource = MockPushMessagingSource();
    final registrationService = MockNotificationRegistrationService();
    final foregroundDispatcher = MockForegroundNotificationDispatcher();
    final openDispatcher = MockNotificationOpenDispatcher();

    Future<void> recordLocalInitialize(_) async => events.add("local.initialize");

    Future<void> recordPushInitialize(_) async => events.add("push.initialize");

    Future<void> recordRegistrationStart(_) async => events.add("registration.start");

    Future<void> recordForegroundStart(_) async => events.add("foreground.start");

    Future<void> recordOpenStart(_) async => events.add("open.start");

    when(localNotificationClient.initialize).thenAnswer(recordLocalInitialize);
    when(pushMessagingSource.initialize).thenAnswer(recordPushInitialize);
    when(registrationService.start).thenAnswer(recordRegistrationStart);
    when(foregroundDispatcher.start).thenAnswer(recordForegroundStart);
    when(openDispatcher.start).thenAnswer(recordOpenStart);

    await startNotificationStartup(
      localNotificationClient: localNotificationClient,
      pushMessagingSource: pushMessagingSource,
      notificationRegistrationService: registrationService,
      foregroundNotificationDispatcher: foregroundDispatcher,
      notificationOpenDispatcher: openDispatcher,
    );

    expect(events, [
      "local.initialize",
      "push.initialize",
      "registration.start",
      "foreground.start",
      "open.start",
    ]);
  });

  test("later notification startup steps still run if registration fails", () async {
    final events = <String>[];
    final localNotificationClient = MockLocalNotificationClient();
    final pushMessagingSource = MockPushMessagingSource();
    final registrationService = MockNotificationRegistrationService();
    final foregroundDispatcher = MockForegroundNotificationDispatcher();
    final openDispatcher = MockNotificationOpenDispatcher();

    when(localNotificationClient.initialize).thenAnswer((_) async => events.add("local.initialize"));
    when(pushMessagingSource.initialize).thenAnswer((_) async => events.add("push.initialize"));
    when(registrationService.start).thenAnswer((_) async {
      events.add("registration.start");
      throw Exception("boom");
    });
    when(foregroundDispatcher.start).thenAnswer((_) async => events.add("foreground.start"));
    when(openDispatcher.start).thenAnswer((_) async => events.add("open.start"));

    await startNotificationStartup(
      localNotificationClient: localNotificationClient,
      pushMessagingSource: pushMessagingSource,
      notificationRegistrationService: registrationService,
      foregroundNotificationDispatcher: foregroundDispatcher,
      notificationOpenDispatcher: openDispatcher,
    );

    expect(events, [
      "local.initialize",
      "push.initialize",
      "registration.start",
      "foreground.start",
      "open.start",
    ]);
  });
}
