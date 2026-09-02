import "dart:convert";

import "package:flutter/foundation.dart" show TargetPlatform, debugDefaultTargetPlatformOverride;
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop/core/platform/desktop_local_notification_client.dart";
import "package:sesori_shared/sesori_shared.dart";

void main() {
  setUpAll(() {
    registerFallbackValue(
      const InitializationSettings(
        macOS: DarwinInitializationSettings(),
        linux: LinuxInitializationSettings(defaultActionName: "Open Sesori"),
      ),
    );
    registerFallbackValue(const NotificationDetails(macOS: DarwinNotificationDetails()));
  });

  late _MockFlutterLocalNotificationsPlugin plugin;
  late DesktopLocalNotificationClient client;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    plugin = _MockFlutterLocalNotificationsPlugin();
    client = DesktopLocalNotificationClient(plugin: plugin);
    when(plugin.getNotificationAppLaunchDetails).thenAnswer((_) async => null);
    when(
      () => plugin.initialize(
        settings: any(named: "settings"),
        onDidReceiveNotificationResponse: any(named: "onDidReceiveNotificationResponse"),
      ),
    ).thenAnswer((_) async => true);
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await client.dispose();
  });

  test("initializes macOS, Linux, and Windows notification settings once", () async {
    await client.initialize();
    await client.initialize();

    final settings =
        verify(
              () => plugin.initialize(
                settings: captureAny(named: "settings"),
                onDidReceiveNotificationResponse: any(named: "onDidReceiveNotificationResponse"),
              ),
            ).captured.single
            as InitializationSettings;
    expect(settings.macOS, isNotNull);
    expect(settings.linux, isNotNull);
    expect(settings.windows, isNotNull);
    verify(plugin.getNotificationAppLaunchDetails).called(1);
  });

  test("consumes one typed open request from notification launch details", () async {
    when(plugin.getNotificationAppLaunchDetails).thenAnswer(
      (_) async => NotificationAppLaunchDetails(
        true,
        notificationResponse: NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotification,
          payload: jsonEncode(<String, dynamic>{
            "sessionId": "session-1",
            "projectId": "project-1",
            "sessionTitle": "Session title",
          }),
        ),
      ),
    );

    await client.initialize();

    final first = await client.getInitialNotificationOpen();
    expect(first?.sessionId, "session-1");
    expect(first?.projectId, "project-1");
    expect(await client.getInitialNotificationOpen(), isNull);
  });

  test("skips unsupported launch-detail lookup on Linux", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    await client.initialize();

    verifyNever(plugin.getNotificationAppLaunchDetails);
    verify(
      () => plugin.initialize(
        settings: any(named: "settings"),
        onDidReceiveNotificationResponse: any(named: "onDidReceiveNotificationResponse"),
      ),
    ).called(1);
  });

  test("shows category-only content with deterministic session identity", () async {
    when(
      () => plugin.show(
        id: any(named: "id"),
        title: any(named: "title"),
        body: any(named: "body"),
        notificationDetails: any(named: "notificationDetails"),
        payload: any(named: "payload"),
      ),
    ).thenAnswer((_) async {});

    await client.show(
      title: "Session title",
      body: "Question waiting for your response",
      category: NotificationCategory.aiInteraction,
      sessionId: "session-1",
      projectId: "project-1",
      sessionTitle: "Session title",
    );

    final verification = verify(
      () => plugin.show(
        id: captureAny(named: "id"),
        title: "Session title",
        body: "Question waiting for your response",
        notificationDetails: any(named: "notificationDetails"),
        payload: captureAny(named: "payload"),
      ),
    );
    final captured = verification.captured;
    expect(captured[0], sessionNotificationId(sessionId: "session-1"));
    expect(
      jsonDecode(captured[1] as String),
      <String, dynamic>{
        "sessionId": "session-1",
        "projectId": "project-1",
        "sessionTitle": "Session title",
      },
    );
  });

  test("emits a typed open request from a notification response", () async {
    final open = client.notificationOpenedStream.first;

    client.handleNotificationResponseForTesting(
      response: NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: jsonEncode(<String, dynamic>{
          "sessionId": "session-1",
          "projectId": "project-1",
          "sessionTitle": "Session title",
        }),
      ),
    );

    final request = await open;
    expect(request.sessionId, "session-1");
    expect(request.projectId, "project-1");
    expect(request.sessionTitle, "Session title");
  });

  test("rejects malformed and incomplete notification payloads", () {
    expect(client.notificationOpenFromPayloadForTesting(payload: "not-json"), isNull);
    expect(
      client.notificationOpenFromPayloadForTesting(
        payload: jsonEncode(<String, dynamic>{"sessionId": "session-1"}),
      ),
      isNull,
    );
  });

  test("cancels one session or all delivered notifications", () async {
    when(() => plugin.cancel(id: any(named: "id"))).thenAnswer((_) async {});
    when(plugin.cancelAll).thenAnswer((_) async {});

    client.cancelForSession(sessionId: "session-1");
    await Future<void>.delayed(Duration.zero);
    await client.cancelAll();

    verify(() => plugin.cancel(id: sessionNotificationId(sessionId: "session-1"))).called(1);
    verify(plugin.cancelAll).called(1);
  });

  test("session cancellation failures stay best effort", () async {
    when(() => plugin.cancel(id: any(named: "id"))).thenThrow(StateError("native cancellation failed"));

    client.cancelForSession(sessionId: "session-1");
    await Future<void>.delayed(Duration.zero);

    verify(() => plugin.cancel(id: sessionNotificationId(sessionId: "session-1"))).called(1);
  });
}

class _MockFlutterLocalNotificationsPlugin() extends Mock implements FlutterLocalNotificationsPlugin;
