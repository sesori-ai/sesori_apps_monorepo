import "package:sesori_shared/sesori_shared.dart";

import "../../errors/remote_failure_reason.dart";
import "session_activity_info.dart";
import "session_list_item_state.dart";

/// Absence from the inventory means this project has not been requested.
sealed class const RecentSessionsEntry();

/// Loading without useful retained rows, including an initial read or retry.
final class RecentSessionsLoading() extends RecentSessionsEntry;

final class const RecentSessionsFailed({required final RemoteFailureReason reason}) extends RecentSessionsEntry;

/// Immutable source data and its service-owned active-list projection.
/// Keeping archived source rows allows later updates to preserve PR metadata.
final class const RecentSessionsLoaded({
  required final List<Session> sourceSessions,
  required final List<Session> visibleSessions,
  required final Map<String, SessionActivityInfo> activityBySessionId,
  required final Map<String, SessionListItemState> listStateBySessionId,
}) extends RecentSessionsEntry;
