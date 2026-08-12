import "dart:io";

import "completion_notifier.dart";
import "push_rate_limiter.dart";
import "push_session_state_tracker_types.dart";

class const PushMaintenanceTelemetrySnapshot({
  required final double? rssMb,
  required final int sessions,
  required final int idleRoots,
  required final int prunableRoots,
  required final int messageRoles,
  required final int assistantTextSessions,
  required final int assistantTextChars,
  required final int trackerPermissionRequests,
  required final int notifierPermissionRequests,
  required final int completionSentRoots,
  required final int abortedRoots,
  required final int rateLimiterKeys,
}) {
  Map<String, Object?> toDebugFields() {
    return {
      "rss_mb": rssMb,
      "sessions": sessions,
      "idle_roots": idleRoots,
      "prunable_roots": prunableRoots,
      "message_roles": messageRoles,
      "assistant_text_sessions": assistantTextSessions,
      "assistant_text_chars": assistantTextChars,
      "tracker_permission_requests": trackerPermissionRequests,
      "notifier_permission_requests": notifierPermissionRequests,
      "completion_sent_roots": completionSentRoots,
      "aborted_roots": abortedRoots,
      "rate_limiter_keys": rateLimiterKeys,
    };
  }

  String toLogMessage() {
    final fields = toDebugFields().entries.map((entry) => "${entry.key}=${_formatFieldValue(entry.value)}").join(" ");
    return "[push] maintenance $fields";
  }
}

class const PushMaintenanceTelemetryBuilder({
  required final CompletionNotifier _completionNotifier,
  required final PushRateLimiter _rateLimiter,
  required final int? Function() _rssBytesReader,
}) {
  PushMaintenanceTelemetrySnapshot build({required PushSessionTelemetrySnapshot trackerSnapshot}) {
    final rssBytes = _rssBytesReader();
    return PushMaintenanceTelemetrySnapshot(
      rssMb: rssBytes == null ? null : rssBytes / (1024 * 1024),
      sessions: trackerSnapshot.sessionCount,
      idleRoots: trackerSnapshot.idleRootCount,
      prunableRoots: trackerSnapshot.prunableRoots.length,
      messageRoles: trackerSnapshot.messageRoleCount,
      assistantTextSessions: trackerSnapshot.latestAssistantTextCount,
      assistantTextChars: trackerSnapshot.latestAssistantTextCharCount,
      trackerPermissionRequests: trackerSnapshot.permissionRequestCount,
      notifierPermissionRequests: _completionNotifier.permissionRequestCount,
      completionSentRoots: _completionNotifier.completionSentRootCount,
      abortedRoots: _completionNotifier.abortedRootCount,
      rateLimiterKeys: _rateLimiter.retainedKeyCount,
    );
  }
}

int? readCurrentRssBytes() {
  try {
    return ProcessInfo.currentRss;
  } catch (_) {
    return null;
  }
}

String _formatFieldValue(Object? value) {
  return switch (value) {
    null => "null",
    double() => value.toStringAsFixed(2),
    _ => "$value",
  };
}
