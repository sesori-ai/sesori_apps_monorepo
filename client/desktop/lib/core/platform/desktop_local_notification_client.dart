import "dart:async";
import "dart:convert";

import "package:flutter/foundation.dart" show TargetPlatform, defaultTargetPlatform, visibleForTesting;
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Desktop-shell implementation of the shared local-notification seam.
@LazySingleton(as: LocalNotificationClient)
class DesktopLocalNotificationClient({required final FlutterLocalNotificationsPlugin plugin})
    implements LocalNotificationClient {
  final FlutterLocalNotificationsPlugin _plugin = plugin;
  final StreamController<NotificationOpenRequest> _notificationOpenedController =
      StreamController<NotificationOpenRequest>.broadcast();

  NotificationOpenRequest? _initialNotificationOpen;
  bool _initialNotificationOpenConsumed = false;
  bool _initialized = false;

  static const WindowsInitializationSettings _windowsInitializationSettings = WindowsInitializationSettings(
    appName: "Sesori",
    appUserModelId: "com.sesori.desktop",
    guid: "a89e49d2-6318-49df-9147-f46c003d2b56",
  );

  @override
  Stream<NotificationOpenRequest> get notificationOpenedStream => _notificationOpenedController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    // The Linux implementation does not expose application-launch details.
    // Notification clicks still arrive through the initialized response stream.
    final launchDetails = defaultTargetPlatform == TargetPlatform.linux
        ? null
        : await _plugin.getNotificationAppLaunchDetails();
    _initialNotificationOpen = _notificationOpenFromPayload(
      payload: launchDetails?.didNotificationLaunchApp ?? false ? launchDetails?.notificationResponse?.payload : null,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        macOS: DarwinInitializationSettings(),
        linux: LinuxInitializationSettings(defaultActionName: "Open Sesori"),
        windows: _windowsInitializationSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _initialized = true;
  }

  @override
  Future<NotificationOpenRequest?> getInitialNotificationOpen() async {
    if (_initialNotificationOpenConsumed) {
      return null;
    }
    _initialNotificationOpenConsumed = true;
    return _initialNotificationOpen;
  }

  @visibleForTesting
  void handleNotificationResponseForTesting({required NotificationResponse response}) {
    _onNotificationResponse(response);
  }

  @visibleForTesting
  NotificationOpenRequest? notificationOpenFromPayloadForTesting({required String? payload}) {
    return _notificationOpenFromPayload(payload: payload);
  }

  NotificationOpenRequest? _notificationOpenFromPayload({required String? payload}) {
    if (payload == null || payload.isEmpty) {
      return null;
    }
    try {
      final tapEvent = LocalNotificationPayload.fromJson(jsonDecodeMap(payload));
      final sessionId = tapEvent.sessionId;
      final projectId = tapEvent.projectId;
      final accountId = tapEvent.accountId;
      if (sessionId == null || projectId == null || accountId == null) {
        return null;
      }
      return NotificationOpenRequest(
        projectId: projectId,
        sessionId: sessionId,
        sessionTitle: tapEvent.sessionTitle,
        accountId: accountId,
      );
    } on Object catch (error, stackTrace) {
      logw("Failed to parse desktop local-notification payload", error, stackTrace);
      return null;
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final openRequest = _notificationOpenFromPayload(payload: response.payload);
    if (openRequest != null && !_notificationOpenedController.isClosed) {
      _notificationOpenedController.add(openRequest);
    }
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    required NotificationCategory category,
    required String? sessionId,
    required String? projectId,
    required String? sessionTitle,
    required String? accountId,
  }) async {
    final id = sessionId == null
        ? DateTime.now().millisecondsSinceEpoch.remainder(2147483647)
        : sessionNotificationId(sessionId: sessionId);
    final payload = jsonEncode(
      LocalNotificationPayload(
        sessionId: sessionId,
        projectId: projectId,
        sessionTitle: sessionTitle,
        accountId: accountId,
      ).toJson(),
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
      payload: payload,
    );
  }

  @override
  void cancelForSession({required String sessionId}) {
    unawaited(_cancelForSession(sessionId: sessionId));
  }

  Future<void> _cancelForSession({required String sessionId}) async {
    try {
      await _plugin.cancel(id: sessionNotificationId(sessionId: sessionId));
    } on Object catch (error, stackTrace) {
      logw("Failed to cancel desktop notification for session", error, stackTrace);
    }
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  @disposeMethod
  Future<void> dispose() => _notificationOpenedController.close();
}
