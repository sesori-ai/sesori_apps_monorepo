import "package:sesori_shared/sesori_shared.dart";

import "notification_open_request.dart";
import "push_notification_message.dart";

abstract interface class PushMessagingSource() {
  Future<void> initialize();

  DevicePlatform get devicePlatform;

  /// Asks the messaging provider to register this installation. The resulting
  /// Firebase Installation ID (FID) arrives on [registeredFidStream] rather
  /// than as a return value.
  Future<void> register();

  /// Stops the messaging provider delivering to this installation's FID and
  /// retires that FID, so the next [register] reports a different one and the
  /// old FID can no longer receive pushes anywhere.
  Future<void> unregister();

  /// Emits the FID each time this installation is registered, whether a
  /// [register] call or the provider itself started the registration.
  Stream<String> get registeredFidStream;

  Stream<PushNotificationMessage> get foregroundMessageStream;

  Future<NotificationOpenRequest?> getInitialNotificationOpen();

  Stream<NotificationOpenRequest> get notificationOpenedStream;
}
