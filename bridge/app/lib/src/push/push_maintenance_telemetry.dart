import "dart:io";

import "completion_notifier.dart";
import "push_rate_limiter.dart";
import "push_session_state_tracker_types.dart";

class PushMaintenanceTelemetrySnapshot {
  final double? rssMb;
  final int sessions;
  final int idleRoots;
  final int prunableRoots;
  final int messageRoles;
  final int assistantTextSessions;
  final int assistantTextChars;
  final int trackerPermissionRequests;
  final int notifierPermissionRequests;
  final int completionSentRoots;
  final int abortedRoots;
  final int rateLimiterKeys;

  const PushMaintenanceTelemetrySnapshot({
    required this.rssMb,
    required this.sessions,
    required this.idleRoots,
    required this.prunableRoots,
    required this.messageRoles,
    required this.assistantTextSessions,
    required this.assistantTextChars,
    required this.trackerPermissionRequests,
    required this.notifierPermissionRequests,
    required this.completionSentRoots,
    required this.abortedRoots,
    required this.rateLimiterKeys,
  });

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

class PushMaintenanceTelemetryBuilder {
  final CompletionNotifier _completionNotifier;
  final PushRateLimiter _rateLimiter;
  final int? Function() _rssBytesReader;

  const PushMaintenanceTelemetryBuilder({
    required CompletionNotifier completionNotifier,
    required PushRateLimiter rateLimiter,
    required int? Function() rssBytesReader,
  }) : _completionNotifier = completionNotifier,
       _rateLimiter = rateLimiter,
       _rssBytesReader = rssBytesReader;

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
