import "../../repositories/models/pull_request_monitor_config.dart";

/// What one `configure_pr_monitor` call changes; a null field stays as it
/// is.
final class const PullRequestConfigChange({
  required final PullRequestAutoMergeDefaultChange? autoMerge,
  required final int? quietMinutes,
  required final int? ciWaitMinutes,
  required final int? idleReminderMinutes,
}) {
  PullRequestMonitorConfig timingsAppliedTo({required PullRequestMonitorConfig config}) => config.copyWith(
    quietMinutes: quietMinutes ?? config.quietMinutes,
    ciWaitMinutes: ciWaitMinutes ?? config.ciWaitMinutes,
    idleReminderMinutes: idleReminderMinutes ?? config.idleReminderMinutes,
  );
}

/// A change to where auto-merge is on by default.
sealed class const PullRequestAutoMergeDefaultChange() {
  PullRequestMonitorConfig appliedTo({required PullRequestMonitorConfig config});
}

/// Every repository's default, except those with their own setting.
final class const PullRequestGlobalAutoMerge({required final bool enabled}) extends PullRequestAutoMergeDefaultChange {
  @override
  PullRequestMonitorConfig appliedTo({required PullRequestMonitorConfig config}) => config.copyWith(autoMerge: enabled);
}

/// [repositoryKey] is a lowercased `owner/repo`.
final class const PullRequestRepositoryAutoMerge({required final String repositoryKey, required final bool enabled})
    extends PullRequestAutoMergeDefaultChange {
  @override
  PullRequestMonitorConfig appliedTo({required PullRequestMonitorConfig config}) =>
      config.copyWith(repositoryAutoMerge: {...config.repositoryAutoMerge, repositoryKey: enabled});
}

/// Removes [repositoryKey]'s own setting, so it follows the global default.
final class const PullRequestRepositoryAutoMergeCleared({required final String repositoryKey})
    extends PullRequestAutoMergeDefaultChange {
  @override
  PullRequestMonitorConfig appliedTo({required PullRequestMonitorConfig config}) => config.copyWith(
    repositoryAutoMerge: {...config.repositoryAutoMerge}..remove(repositoryKey),
  );
}
