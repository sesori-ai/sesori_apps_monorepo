import "package:firebase_messaging/firebase_messaging.dart";

/// Injectable access to the static Firebase Messaging APIs.
class FirebaseMessagingStaticAdapter {
  FirebaseMessagingStaticAdapter.enabled()
    : foregroundMessageStream = FirebaseMessaging.onMessage,
      notificationOpenedStream = FirebaseMessaging.onMessageOpenedApp,
      _registerBackgroundHandler = FirebaseMessaging.onBackgroundMessage;

  const FirebaseMessagingStaticAdapter.disabled()
    : foregroundMessageStream = const Stream.empty(),
      notificationOpenedStream = const Stream.empty(),
      _registerBackgroundHandler = _ignoreBackgroundHandler;

  final Stream<RemoteMessage> foregroundMessageStream;
  final Stream<RemoteMessage> notificationOpenedStream;
  final void Function(BackgroundMessageHandler handler) _registerBackgroundHandler;

  void registerBackgroundHandler({required BackgroundMessageHandler handler}) {
    _registerBackgroundHandler(handler);
  }
}

void _ignoreBackgroundHandler(BackgroundMessageHandler handler) {}
