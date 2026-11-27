import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "session_scheduled_mark.freezed.dart";

/// What a session row says about Sesori waking the session again by itself,
/// or about the pull requests the bridge watches for it.
@Freezed()
sealed class SessionScheduledMark with _$SessionScheduledMark {
  /// Nothing wakes the session, and no scheduled task started it.
  const factory none() = SessionScheduledMarkNone;

  /// A wake-up or a same-session task will wake the session: the soonest
  /// one's [name] and when, in UTC milliseconds.
  const factory armed({required String name, required int nextAt}) = SessionScheduledMarkArmed;

  /// The bridge watches pull requests for the session: the one that needs
  /// the user most, and how many [others] there are.
  const factory watchingPullRequests({required SessionPullRequestWatch lead, required int others}) =
      SessionScheduledMarkWatchingPullRequests;

  /// A scheduled task started the session, but nothing will wake it again.
  /// The row names no task: its name usually repeats the session's title.
  const factory fromTask() = SessionScheduledMarkFromTask;

  /// An older bridge that does not report what wakes the session: the task
  /// that started it, as rows showed it before.
  const factory legacyTask({required SessionScheduledTaskMark task}) = SessionScheduledMarkLegacyTask;
}
