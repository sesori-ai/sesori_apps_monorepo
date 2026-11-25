import "package:freezed_annotation/freezed_annotation.dart";

part "pull_request_monitor_config.freezed.dart";
part "pull_request_monitor_config.g.dart";

/// The PR monitor's settings on this computer, set with
/// `configure_pr_monitor`.
@freezed
sealed class const PullRequestMonitorConfig._() with _$PullRequestMonitorConfig {
  const factory({
    /// Whether a watch started without choosing auto-merge gets it.
    required bool autoMerge,

    /// Repositories whose own setting replaces [autoMerge], by lowercased
    /// `owner/repo`.
    required Map<String, bool> repositoryAutoMerge,

    /// How long a report waits after the latest activity, so a burst arrives
    /// as one report.
    required int quietMinutes,

    /// How long a due report waits for running CI before it goes out anyway.
    required int ciWaitMinutes,

    /// How long an open PR stays still before its watchers are reminded of
    /// it; null sends no reminders.
    required int? idleReminderMinutes,
  }) = _PullRequestMonitorConfig;

  /// The plugin's timings, with auto-merge off everywhere.
  static const PullRequestMonitorConfig defaults = PullRequestMonitorConfig(
    autoMerge: false,
    repositoryAutoMerge: {},
    quietMinutes: 2,
    ciWaitMinutes: 30,
    idleReminderMinutes: 25,
  );

  factory fromJson(Map<String, dynamic> json) => _$PullRequestMonitorConfigFromJson(json);

  Duration get quietWindow => Duration(minutes: quietMinutes);

  Duration get ciWait => Duration(minutes: ciWaitMinutes);

  /// Null when reminders are off.
  Duration? get idleReminderDelay => switch (idleReminderMinutes) {
    final minutes? => Duration(minutes: minutes),
    null => null,
  };

  /// The auto-merge default for [repositoryKey], a lowercased `owner/repo`.
  bool autoMergeFor({required String repositoryKey}) => repositoryAutoMerge[repositoryKey] ?? autoMerge;
}
