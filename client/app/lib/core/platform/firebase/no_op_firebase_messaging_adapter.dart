import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";

/// Type-compatible Firebase Messaging implementation for Firebase-disabled builds.
class NoOpFirebaseMessagingAdapter implements FirebaseMessaging {
  NoOpFirebaseMessagingAdapter({required FirebaseApp app}) : _app = app;

  static const NotificationSettings _notificationSettings = NotificationSettings(
    alert: AppleNotificationSetting.notSupported,
    announcement: AppleNotificationSetting.notSupported,
    authorizationStatus: AuthorizationStatus.denied,
    badge: AppleNotificationSetting.notSupported,
    carPlay: AppleNotificationSetting.notSupported,
    lockScreen: AppleNotificationSetting.notSupported,
    notificationCenter: AppleNotificationSetting.notSupported,
    showPreviews: AppleShowPreviewSetting.notSupported,
    timeSensitive: AppleNotificationSetting.notSupported,
    criticalAlert: AppleNotificationSetting.notSupported,
    sound: AppleNotificationSetting.notSupported,
    providesAppNotificationSettings: AppleNotificationSetting.notSupported,
  );

  FirebaseApp _app;

  @override
  FirebaseApp get app => _app;

  @override
  set app(FirebaseApp value) => _app = value;

  @override
  Map<dynamic, dynamic> get pluginConstants => const {};

  @override
  bool get isAutoInitEnabled => false;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;

  @override
  Future<void> deleteToken() async {}

  @override
  Future<String?> getAPNSToken() async => null;

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async => null;

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<NotificationSettings> getNotificationSettings() async => _notificationSettings;

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async => _notificationSettings;

  @override
  Future<void> setAutoInitEnabled(bool enabled) async {}

  @override
  Future<void> setDeliveryMetricsExportToBigQuery(bool enabled) async {}

  @override
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) async {}

  @override
  Future<void> subscribeToTopic(String topic) async {}

  @override
  Future<void> unsubscribeFromTopic(String topic) async {}
}
