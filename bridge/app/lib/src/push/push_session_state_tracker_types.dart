class PushSessionMaintenancePolicy {
  static const rootIdlePruneTtl = Duration(minutes: 30);
  static const messageRoleTtl = Duration(minutes: 30);
  static const messageRoleHardCap = 10000;
}

class PushPrunableRoot {
  final String rootSessionId;
  final DateTime idleSince;
  final int retainedSessionCount;

  const PushPrunableRoot({
    required this.rootSessionId,
    required this.idleSince,
    required this.retainedSessionCount,
  });
}

class PushPrunedSubtree {
  final String rootSessionId;
  final List<String> prunedSessionIds;
  final int removedSessionCount;
  final int removedMessageRoleCount;
  final int removedPermissionMappingCount;

  const PushPrunedSubtree({
    required this.rootSessionId,
    required this.prunedSessionIds,
    required this.removedSessionCount,
    required this.removedMessageRoleCount,
    required this.removedPermissionMappingCount,
  });
}

class PushSessionTelemetrySnapshot {
  final int sessionCount;
  final int rootSessionCount;
  final int idleRootCount;
  final int busySessionCount;
  final int pendingQuestionCount;
  final int pendingPermissionCount;
  final int permissionRequestCount;
  final int previouslyBusyCount;
  final int latestAssistantTextCount;
  final int latestAssistantTextCharCount;
  final int messageRoleCount;
  final int assistantMessageRoleCount;
  final DateTime? oldestSessionActivityAt;
  final DateTime? oldestMessageRoleUpdatedAt;
  final List<PushPrunableRoot> prunableRoots;

  const PushSessionTelemetrySnapshot({
    required this.sessionCount,
    required this.rootSessionCount,
    required this.idleRootCount,
    required this.busySessionCount,
    required this.pendingQuestionCount,
    required this.pendingPermissionCount,
    required this.permissionRequestCount,
    required this.previouslyBusyCount,
    required this.latestAssistantTextCount,
    required this.latestAssistantTextCharCount,
    required this.messageRoleCount,
    required this.assistantMessageRoleCount,
    required this.oldestSessionActivityAt,
    required this.oldestMessageRoleUpdatedAt,
    required this.prunableRoots,
  });
}
