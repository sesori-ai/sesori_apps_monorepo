import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../di/firebase_register_module.dart";

/// The [PushMessagingSource] for builds with no Firebase SDK (Android profile).
///
/// This is registered rather than omitted because `NotificationRegistrationService`
/// is resolved from the settings and profile screens on every platform, not only
/// from the Firebase-guarded notification startup.
///
/// There is no messaging SDK to register with, so [registeredFidStream] never
/// emits an installation ID — which is what keeps server registration from ever
/// running here.
@firebaseDisabledEnvironment
@LazySingleton(as: PushMessagingSource)
class NoOpPushMessagingSource() implements PushMessagingSource {
  @override
  Future<void> initialize() async {}

  /// Never read in this environment: server registration is reached only
  /// through a [registeredFidStream] event, which never occurs here. Reporting
  /// a platform beats throwing, because the settings screen resolves this
  /// service and a throw would take the screen down over a value nothing
  /// consumes.
  @override
  DevicePlatform get devicePlatform => DevicePlatform.android;

  @override
  Future<void> register() async {}

  @override
  Future<void> unregister() async {}

  @override
  Stream<String> get registeredFidStream => const Stream<String>.empty();

  @override
  Stream<PushNotificationMessage> get foregroundMessageStream => const Stream<PushNotificationMessage>.empty();

  @override
  Future<NotificationOpenRequest?> getInitialNotificationOpen() async => null;

  @override
  Stream<NotificationOpenRequest> get notificationOpenedStream => const Stream<NotificationOpenRequest>.empty();
}
