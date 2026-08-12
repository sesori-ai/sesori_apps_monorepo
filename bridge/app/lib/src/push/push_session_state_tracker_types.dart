class PushSessionMaintenancePolicy() {
  static const rootIdlePruneTtl = Duration(minutes: 30);
  static const messageRoleTtl = Duration(minutes: 30);
  static const messageRoleHardCap = 10000;
}

class const PushPrunableRoot({
  required final String rootSessionId,
  required final DateTime idleSince,
  required final int retainedSessionCount,
});

class const PushPrunedSubtree({
  required final String rootSessionId,
  required final List<String> prunedSessionIds,
  required final int removedSessionCount,
  required final int removedMessageRoleCount,
  required final int removedPermissionMappingCount,
});

class const PushSessionTelemetrySnapshot({
  required final int sessionCount,
  required final int rootSessionCount,
  required final int idleRootCount,
  required final int busySessionCount,
  required final int pendingQuestionCount,
  required final int pendingPermissionCount,
  required final int permissionRequestCount,
  required final int previouslyBusyCount,
  required final int latestAssistantTextCount,
  required final int latestAssistantTextCharCount,
  required final int messageRoleCount,
  required final int assistantMessageRoleCount,
  required final DateTime? oldestSessionActivityAt,
  required final DateTime? oldestMessageRoleUpdatedAt,
  required final List<PushPrunableRoot> prunableRoots,
});
