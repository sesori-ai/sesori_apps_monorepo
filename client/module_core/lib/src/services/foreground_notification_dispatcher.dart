import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../logging/logging.dart";
import "../platform/local_notification_client.dart";
import "../platform/push_messaging_source.dart";
import "../platform/push_notification_message.dart";
import "notification_preferences_service.dart";

@lazySingleton
class ForegroundNotificationDispatcher({
  required NotificationPreferencesService notificationPreferencesService,
  required final LocalNotificationClient _localNotificationClient,
  required final PushMessagingSource _pushMessagingSource,
}) {
  final NotificationPreferencesService _preferencesService = notificationPreferencesService;
  StreamSubscription<PushNotificationMessage>? _foregroundMessageSubscription;
  bool _started = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_disposed) {
      logw("ForegroundNotificationDispatcher.start() called after dispose");
      return;
    }
    if (_started) {
      logw("ForegroundNotificationDispatcher.start() called more than once; ignoring");
      return;
    }

    _started = true;
    _foregroundMessageSubscription = _pushMessagingSource.foregroundMessageStream.listen(
      _onForegroundMessage,
      onError: _onForegroundMessageStreamError,
    );
  }

  void _onForegroundMessage(PushNotificationMessage message) {
    unawaited(
      _dispatchForegroundMessage(message: message).catchError((Object error, StackTrace stackTrace) {
        logw("Failed to dispatch foreground notification", error, stackTrace);
      }),
    );
  }

  Future<void> _dispatchForegroundMessage({required PushNotificationMessage message}) async {
    final notificationData = NotificationData.fromJson(message.data);
    final isEnabled = await _preferencesService.isEnabled(category: notificationData.category);
    if (!isEnabled) {
      return;
    }

    final title = message.title;
    final body = message.body;
    if (title == null || title.isEmpty || body == null || body.isEmpty) {
      return;
    }

    await _localNotificationClient.show(
      title: title,
      body: body,
      category: notificationData.category,
      sessionId: notificationData.sessionId,
      projectId: notificationData.projectId,
      sessionTitle: notificationData.sessionId == null ? null : title,
      accountId: null,
    );
  }

  // ignore: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters
  void _onForegroundMessageStreamError(Object error, StackTrace stackTrace) {
    loge("Foreground notification stream error", error, stackTrace);
  }

  @disposeMethod
  Future<void> dispose() async {
    _disposed = true;
    await _foregroundMessageSubscription?.cancel();
    _foregroundMessageSubscription = null;
  }
}
