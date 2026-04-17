import "dart:async";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../auth/token_refresh_exception.dart";
import "completion_notifier.dart";
import "push_maintenance_telemetry.dart";
import "push_notification_client.dart";
import "push_notification_content_builder.dart";
import "push_rate_limiter.dart";
import "push_send_exception.dart";
import "push_session_state_tracker.dart";

class PushDispatcher {
  final PushNotificationClient _client;
  final PushRateLimiter _rateLimiter;
  final PushSessionStateTracker _tracker;
  final CompletionNotifier _completionNotifier;
  final PushNotificationContentBuilder _contentBuilder;
  final PushMaintenanceTelemetryBuilder _telemetryBuilder;
  PushMaintenanceTelemetrySnapshot? _lastMaintenanceTelemetry;

  PushDispatcher({
    required PushNotificationClient client,
    required PushRateLimiter rateLimiter,
    required PushSessionStateTracker tracker,
    required CompletionNotifier completionNotifier,
    required PushNotificationContentBuilder contentBuilder,
    required PushMaintenanceTelemetryBuilder telemetryBuilder,
  }) : _client = client,
       _rateLimiter = rateLimiter,
       _tracker = tracker,
       _completionNotifier = completionNotifier,
       _contentBuilder = contentBuilder,
       _telemetryBuilder = telemetryBuilder;

  @visibleForTesting
  PushMaintenanceTelemetrySnapshot? get lastMaintenanceTelemetry => _lastMaintenanceTelemetry;

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

  void dispatchCompletionForRoot({required String rootSessionId}) {
    final sessionTitle = _tracker.getSessionTitle(rootSessionId);
    final latestAssistantText = _tracker.getLatestAssistantText(rootSessionId);

    final title = _contentBuilder.truncateTitle(
      (sessionTitle == null || sessionTitle.trim().isEmpty) ? "Session completed" : sessionTitle,
    );
    final body = _contentBuilder.truncateToWords(
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

  void runMaintenancePass() {
    _runMaintenanceStep(
      label: "root-prune",
      action: () {
        final prunableRoots = _tracker.findPrunableRoots();
        for (final prunableRoot in prunableRoots) {
          _runMaintenanceStep(
            label: "root-prune:${prunableRoot.rootSessionId}",
            action: () {
              final prunedSubtree = _tracker.pruneRootSubtree(rootSessionId: prunableRoot.rootSessionId);
              _completionNotifier.cleanupPrunedRootSubtree(
                rootSessionId: prunableRoot.rootSessionId,
                prunedSessionIds: prunedSubtree.prunedSessionIds,
              );
            },
          );
        }
      },
    );

    _runMaintenanceStep(label: "message-role-prune", action: _tracker.pruneMessageRoleMetadata);
    _runMaintenanceStep(label: "rate-limiter-prune", action: _rateLimiter.pruneStaleEntries);
    _runMaintenanceStep(
      label: "telemetry",
      action: () {
        final snapshot = _telemetryBuilder.build(
          trackerSnapshot: _tracker.createTelemetrySnapshot(),
        );
        _lastMaintenanceTelemetry = snapshot;
        Log.d(snapshot.toLogMessage());
      },
    );
  }

  Future<void> dispose() async {
    _completionNotifier.dispose();
    await _client.dispose();
  }

  void reset() {
    _completionNotifier.reset();
    _tracker.reset();
  }

  void _sendImmediateNotificationIfApplicable(SesoriSseEvent event) {
    final notificationData = _contentBuilder.extractNotificationData(event);
    if (notificationData == null) {
      return;
    }

    _sendNotification(
      category: notificationData.category,
      eventType: notificationData.eventType,
      title: notificationData.title,
      body: notificationData.body,
      sessionId: _contentBuilder.extractSessionId(event),
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

    final payload = _contentBuilder.buildNotificationPayload(
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

  void _runMaintenanceStep({required String label, required void Function() action}) {
    try {
      action();
    } catch (error, stackTrace) {
      Log.w("[push] maintenance step '$label' failed: $error\n$stackTrace");
    }
  }
}
