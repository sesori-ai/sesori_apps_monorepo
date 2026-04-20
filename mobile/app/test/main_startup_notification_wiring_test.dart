import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/main.dart";

class MockLocalNotificationClient extends Mock implements LocalNotificationClient {}

class MockPushMessagingSource extends Mock implements PushMessagingSource {}

class MockNotificationRegistrationService extends Mock implements NotificationRegistrationService {}

class MockForegroundNotificationDispatcher extends Mock implements ForegroundNotificationDispatcher {}

class MockNotificationOpenDispatcher extends Mock implements NotificationOpenDispatcher {}

void main() {
  testWidgets("notification core collaborators start after configureDependencies", (tester) async {
    final events = <String>[];

    void configureDependencies() => events.add("configureDependencies");

    void initializeDeepLinks() => events.add("deepLinks");

    Future<void> startNotificationStartup() async => events.add("notificationStartup");

    void runAppFn(_) => events.add("runApp");

    await bootstrapSesoriApp(
      shouldInitializeFirebase: true,
      configureDependenciesFn: configureDependencies,
      initializeDeepLinks: initializeDeepLinks,
      startNotificationStartupFn: startNotificationStartup,
      runAppFn: runAppFn,
    );

    expect(events, ["configureDependencies", "deepLinks", "notificationStartup", "runApp"]);
  });

  testWidgets("notification startup initializes adapters before starting dispatchers", (tester) async {
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

  testWidgets("later notification startup steps still run if registration fails", (tester) async {
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
