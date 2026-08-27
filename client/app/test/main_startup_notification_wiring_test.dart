import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/main.dart";

class MockLocalNotificationClient() extends Mock implements LocalNotificationClient;

class MockPushMessagingSource() extends Mock implements PushMessagingSource;

class MockNotificationRegistrationService() extends Mock implements NotificationRegistrationService;

class MockForegroundNotificationDispatcher() extends Mock implements ForegroundNotificationDispatcher;

class MockNotificationOpenDispatcher() extends Mock implements NotificationOpenDispatcher;

void main() {
  test("notification core collaborators start after configureDependencies", () async {
    final events = <String>[];
    final startupStarted = Completer<void>();
    final allowStartupFinish = Completer<void>();

    Future<void> configureDependencies() async => events.add("configureDependencies");

    Future<void> startSingularAttribution() async => events.add("singularAttribution");

    void initializeDeepLinks() => events.add("deepLinks");

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
      startSingularAttributionFn: startSingularAttribution,
      initializeDeepLinks: initializeDeepLinks,
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
      "singularAttribution",
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

    allowStartupFinish.complete();
    await Future<void>.delayed(Duration.zero);

    expect(
      events,
      [
        "configureDependencies",
        "singularAttribution",
        "deepLinks",
        "productAnalytics",
        "analyticsRoutes",
        "notificationStartup.start",
        "readAppearance",
        "readChatInputMode",
        "runApp",
        "notificationStartup.done",
      ],
    );
  });

  test("Singular startup failure does not block app bootstrap", () async {
    final events = <String>[];

    await bootstrapSesoriApp(
      shouldInitializeFirebase: false,
      configureDependenciesFn: () async => events.add("configureDependencies"),
      startSingularAttributionFn: () async {
        events.add("singularAttribution");
        throw StateError("startup failed");
      },
      initializeDeepLinks: () => events.add("deepLinks"),
      startProductAnalyticsFn: () async => events.add("productAnalytics"),
      startAnalyticsRouteListenerFn: () async => events.add("analyticsRoutes"),
      startNotificationStartupFn: () async => events.add("notificationStartup"),
      readAppearanceFn: () async => AppearanceMode.system,
      readChatInputModeFn: () async => ChatInputMode.textFirst,
      runAppFn: (_) => events.add("runApp"),
    );

    expect(events, [
      "configureDependencies",
      "singularAttribution",
      "deepLinks",
      "productAnalytics",
      "analyticsRoutes",
      "runApp",
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
