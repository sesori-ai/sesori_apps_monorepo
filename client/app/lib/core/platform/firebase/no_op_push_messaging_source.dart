import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../di/firebase_register_module.dart";

/// The [PushMessagingSource] for builds with no Firebase SDK (web, Linux,
/// Windows, Android profile).
///
/// This is registered rather than omitted because `NotificationRegistrationService`
/// is resolved from the settings and profile screens on every platform, not only
/// from the Firebase-guarded notification startup.
///
/// There is no messaging SDK to obtain a token from, so [getToken] reports none
/// and every stream stays empty — which is what keeps registration from ever
/// running here.
@firebaseDisabledEnvironment
@LazySingleton(as: PushMessagingSource)
class NoOpPushMessagingSource() implements PushMessagingSource {
  @override
  Future<void> initialize() async {}

  /// Never read in this environment: token registration is reached only through
  /// a non-null [getToken] result or a [tokenRefreshStream] event, and neither
  /// occurs here. Reporting a platform beats throwing, because the settings
  /// screen resolves this service and a throw would take the screen down over a
  /// value nothing consumes.
  @override
  DevicePlatform get devicePlatform => DevicePlatform.android;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> deleteToken() async {}

  @override
  Stream<String> get tokenRefreshStream => const Stream<String>.empty();

  @override
  Stream<PushNotificationMessage> get foregroundMessageStream => const Stream<PushNotificationMessage>.empty();

  @override
  Future<NotificationOpenRequest?> getInitialNotificationOpen() async => null;

  @override
  Stream<NotificationOpenRequest> get notificationOpenedStream => const Stream<NotificationOpenRequest>.empty();
}
