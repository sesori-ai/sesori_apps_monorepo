import "package:freezed_annotation/freezed_annotation.dart";

import "agent_info.dart";
import "plugin_identity.dart";
import "pull_request_info.dart";

part "session.freezed.dart";

part "session.g.dart";

/// Response from `GET /session`.
@Freezed(fromJson: true, toJson: true)
sealed class SessionListResponse with _$SessionListResponse {
  const factory SessionListResponse({
    required List<Session> items,
  }) = _SessionListResponse;

  factory SessionListResponse.fromJson(Map<String, dynamic> json) => _$SessionListResponseFromJson(json);
}

/// Request body for `POST /sessions`.
@Freezed(fromJson: true, toJson: true)
sealed class SessionListRequest with _$SessionListRequest {
  const factory SessionListRequest({
    required String projectId,
    required int? start,
    required int? limit,
    @Default(false) bool waitForPrData,
  }) = _SessionListRequest;

  factory SessionListRequest.fromJson(Map<String, dynamic> json) => _$SessionListRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class Session with _$Session {
  const factory Session({
    required String id,
    // COMPATIBILITY 2026-07-13 (v1.5.0): Old sessions omit pluginId and mean OpenCode. Remove default; require pluginId.
    @Default(legacyMissingPluginId) String pluginId,
    required String projectID,
    required String directory,
    required String? parentID,
    required String? title,
    required SessionTime? time,
    required PullRequestInfo? pullRequest,
    // COMPATIBILITY 2026-07-15 (v1.5.0): Bridges before PR-history support omit pullRequestHistory, which means no legacy history beyond pullRequest. Remove @Default and make the field required after the minimum supported bridge always sends pullRequestHistory.
    @Default(<PullRequestInfo>[]) List<PullRequestInfo> pullRequestHistory,
    required SessionPromptDefaults? promptDefaults,
    // The git branch the session's workspace is checked out on, when the
    // bridge knows one. Worktree sessions carry the branch recorded at
    // creation; plain checkouts carry whatever git currently reports (or last
    // reported). Null means no branch is known — typically a payload from a
    // bridge that predates branch reporting, or a checkout git cannot name.
    required String? branchName,
    @Default(false) bool hasWorktree,
    // Whether this session has unseen activity (new changes the user has not
    // viewed). Backend-computed; advances on activity and is cleared by viewing
    // the session or an explicit mark-as-read. Defaults to false so older
    // payloads (and the baseline) deserialize as "seen".
    @Default(false) bool unseen,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class SessionPromptDefaults with _$SessionPromptDefaults {
  const factory SessionPromptDefaults({
    required String? agent,
    required AgentModel? model,
  }) = _SessionPromptDefaults;

  factory SessionPromptDefaults.fromJson(Map<String, dynamic> json) => _$SessionPromptDefaultsFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class SessionTime with _$SessionTime {
  const factory SessionTime({
    required int created,
    required int updated,
    required int? archived,
  }) = _SessionTime;

  factory SessionTime.fromJson(Map<String, dynamic> json) => _$SessionTimeFromJson(json);
}

/// Session with embedded project info, returned by `/experimental/session`.
///
/// This is the `GlobalInfo` type from the backend server — a [Session] extended
/// with a nullable [SessionProject] that identifies which project the session
/// belongs to.
@Freezed(fromJson: true, toJson: true)
sealed class GlobalSession with _$GlobalSession {
  const factory GlobalSession({
    required String id,
    required String projectID,
    required String directory,
    required String? parentID,
    required String? title,
    required SessionTime? time,
    required SessionProject? project,
  }) = _GlobalSession;

  factory GlobalSession.fromJson(Map<String, dynamic> json) => _$GlobalSessionFromJson(json);
}

/// Lightweight project reference embedded in [GlobalSession].
///
/// This is the `ProjectInfo` / `ProjectSummary` type from the backend server —
/// a subset of [Project] with only `id`, `name`, and `worktree`.
@Freezed(fromJson: true, toJson: true)
sealed class SessionProject with _$SessionProject {
  const factory SessionProject({
    required String id,
    required String? name,
    required String worktree,
  }) = _SessionProject;

  factory SessionProject.fromJson(Map<String, dynamic> json) => _$SessionProjectFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class SessionIdRequest with _$SessionIdRequest {
  const factory SessionIdRequest({
    required String sessionId,
  }) = _SessionIdRequest;

  factory SessionIdRequest.fromJson(Map<String, dynamic> json) => _$SessionIdRequestFromJson(json);
}
