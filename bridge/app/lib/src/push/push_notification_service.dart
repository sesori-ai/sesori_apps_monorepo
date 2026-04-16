import "dart:async";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../auth/token_refresh_exception.dart";
import "completion_notifier.dart";
import "push_maintenance_loop.dart";
import "push_maintenance_telemetry.dart";
import "push_notification_client.dart";
import "push_notification_service_helpers.dart";
import "push_rate_limiter.dart";
import "push_send_exception.dart";
import "push_session_state_tracker.dart";

class PushNotificationService {
  final PushNotificationClient _client;
  final PushRateLimiter _rateLimiter;
  final PushSessionStateTracker _tracker;
  final CompletionNotifier _completionNotifier;
  late final PushMaintenanceLoop _maintenanceLoop;
  late final StreamSubscription<String> _completionSubscription;

  PushNotificationService({
    required PushNotificationClient client,
    required PushRateLimiter rateLimiter,
    required PushSessionStateTracker tracker,
    required CompletionNotifier completionNotifier,
    Duration maintenanceInterval = const Duration(minutes: 10),
    int? Function()? rssBytesReader,
    void Function(String)? debugLogger,
  }) : _client = client,
       _rateLimiter = rateLimiter,
       _tracker = tracker,
       _completionNotifier = completionNotifier {
    _completionSubscription = _completionNotifier.completions.listen(_sendCompletionNotification);
    _maintenanceLoop = PushMaintenanceLoop(
      tracker: _tracker,
      completionNotifier: _completionNotifier,
      rateLimiter: _rateLimiter,
      maintenanceInterval: maintenanceInterval,
      rssBytesReader: rssBytesReader,
      debugLogger: debugLogger,
    );
  }

  @visibleForTesting
  PushMaintenanceTelemetrySnapshot? get lastMaintenanceTelemetry => _maintenanceLoop.lastSnapshot;

  void handleSseEvent(SesoriSseEvent event) {
    _tracker.handleEvent(event);
    _completionNotifier.handleEvent(event);
    _sendImmediateNotificationIfApplicable(event);
  }

  /// Marks a session as user-aborted so the completion notification is
  /// suppressed for the current busy→idle transition.
  void markSessionAborted(String sessionId) {
    _completionNotifier.markSessionAborted(sessionId);
  }

  Future<void> dispose() async {
    _maintenanceLoop.dispose();
    await _completionSubscription.cancel();
    _completionNotifier.dispose();
  }

  void reset() {
    _completionNotifier.reset();
    _tracker.reset();
  }

  void _sendImmediateNotificationIfApplicable(SesoriSseEvent event) {
    final notificationData = extractNotificationData(event);
    if (notificationData == null) {
      return;
    }

    _sendNotification(
      category: notificationData.category,
      eventType: notificationData.eventType,
      title: notificationData.title,
      body: notificationData.body,
      sessionId: extractSessionId(event),
    );
  }

  void _sendCompletionNotification(String rootSessionId) {
    final sessionTitle = _tracker.getSessionTitle(rootSessionId);
    final latestAssistantText = _tracker.getLatestAssistantText(rootSessionId);

    final title = truncateTitle(
      (sessionTitle == null || sessionTitle.trim().isEmpty) ? "Session completed" : sessionTitle,
    );
    final body = truncateToWords(
      (latestAssistantText == null || latestAssistantText.trim().isEmpty) ? "Task completed" : latestAssistantText,
    );

    _tracker.clearLatestAssistantTextForRootSubtree(rootSessionId: rootSessionId);

    _sendNotification(
      category: NotificationCategory.sessionMessage,
      eventType: NotificationEventType.agentTurnCompleted,
      title: title,
      body: body,
      sessionId: rootSessionId,
    );
  }

  void _sendNotification({
    required NotificationCategory category,
    required NotificationEventType eventType,
    required String title,
    required String body,
    required String? sessionId,
  }) {
    final collapseKey = "${category.id}-${sessionId ?? "global"}";
    if (!_rateLimiter.shouldSend(
      category: category,
      collapseKey: collapseKey,
      sessionId: sessionId,
    )) {
      return;
    }

    final payload = buildNotificationPayload(
      category: category,
      eventType: eventType,
      title: title,
      body: body,
      sessionId: sessionId,
      collapseKey: collapseKey,
      projectId: sessionId != null ? _tracker.getSessionProjectId(sessionId: sessionId) : null,
    );

    unawaited(
      _client.sendNotification(payload).catchError((Object e) {
        if (e is TokenRefreshException || (e is PushSendException && e.statusCode == 401)) {
          Log.e("[push] auth failure, credentials may need re-authentication: $e");
        } else {
          Log.w("[push] send error: $e");
        }
      }),
    );
  }
}
