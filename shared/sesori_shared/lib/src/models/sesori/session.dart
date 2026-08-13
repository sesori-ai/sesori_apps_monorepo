import "package:freezed_annotation/freezed_annotation.dart";

import "agent_info.dart";
import "message_part.dart";
import "plugin_identity.dart";
import "pull_request_info.dart";

part "session.freezed.dart";

part "session.g.dart";

/// Response from `GET /session`.
@Freezed(fromJson: true, toJson: true)
sealed class SessionListResponse with _$SessionListResponse {
  const factory({
    required List<Session> items,
  }) = _SessionListResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionListResponseFromJson(json);
}

/// Request body for `POST /sessions`.
@Freezed(fromJson: true, toJson: true)
sealed class SessionListRequest with _$SessionListRequest {
  const factory({
    required String projectId,
    required int? start,
    required int? limit,
    @Default(false) bool waitForPrData,
  }) = _SessionListRequest;

  factory fromJson(Map<String, dynamic> json) => _$SessionListRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class Session with _$Session {
  const factory({
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
    // The branch the bridge created for this session's dedicated worktree.
    // Null means the session has no dedicated worktree or came from a bridge
    // that predates branch reporting.
    required String? branchName,
    @Default(false) bool hasWorktree,
    // Whether this session has unseen activity (new changes the user has not
    // viewed). Backend-computed; advances on activity and is cleared by viewing
    // the session or an explicit mark-as-read. Defaults to false so older
    // payloads (and the baseline) deserialize as "seen".
    @Default(false) bool unseen,
    // COMPATIBILITY 2026-08-13 (v1.9.0): Older bridges omit lastUserActivityAt, which means no durable marker is known. Remove this comment after the minimum supported bridge always sends this field.
    required int? lastUserActivityAt,
  }) = _Session;

  factory fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class SessionPromptDefaults with _$SessionPromptDefaults {
  const factory({
    required String? agent,
    required AgentModel? model,
  }) = _SessionPromptDefaults;

  factory fromJson(Map<String, dynamic> json) => _$SessionPromptDefaultsFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class SessionTime with _$SessionTime {
  const factory({
    required int created,
    required int updated,
    required int? archived,
  }) = _SessionTime;

  factory fromJson(Map<String, dynamic> json) => _$SessionTimeFromJson(json);
}

/// Session with embedded project info, returned by `/experimental/session`.
///
/// This is the `GlobalInfo` type from the backend server — a [Session] extended
/// with a nullable [SessionProject] that identifies which project the session
/// belongs to.
@Freezed(fromJson: true, toJson: true)
sealed class GlobalSession with _$GlobalSession {
  const factory({
    required String id,
    required String projectID,
    required String directory,
    required String? parentID,
    required String? title,
    required SessionTime? time,
    required SessionProject? project,
  }) = _GlobalSession;

  factory fromJson(Map<String, dynamic> json) => _$GlobalSessionFromJson(json);
}

/// Lightweight project reference embedded in [GlobalSession].
///
/// This is the `ProjectInfo` / `ProjectSummary` type from the backend server —
/// a subset of [Project] with only `id`, `name`, and `worktree`.
@Freezed(fromJson: true, toJson: true)
sealed class SessionProject with _$SessionProject {
  const factory({
    required String id,
    required String? name,
    required String worktree,
  }) = _SessionProject;

  factory fromJson(Map<String, dynamic> json) => _$SessionProjectFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class SessionIdRequest with _$SessionIdRequest {
  const factory({
    required String sessionId,
  }) = _SessionIdRequest;

  factory fromJson(Map<String, dynamic> json) => _$SessionIdRequestFromJson(json);
}

/// Request body for `POST /session/messages`.
///
/// A superset of [SessionIdRequest]: both new fields are optional, so an older
/// app's body still decodes and an older bridge ignores what it does not know.
/// Omitting [limit] returns the whole transcript, which is the pre-pagination
/// behavior.
@Freezed(fromJson: true, toJson: true)
sealed class SessionMessagesRequest with _$SessionMessagesRequest {
  const factory({
    required String sessionId,

    /// Maximum messages to return, newest-first from [before]. Null means the
    /// full transcript.
    // COMPATIBILITY 2026-08-08 (v1.7.2): Apps that predate pagination omit limit and mean the full transcript. Make this required and drop the unpaged read path once those apps are unsupported.
    required int? limit,

    /// Exclusive cursor: return messages ordered strictly before this one.
    /// Null starts from the newest message.
    required int? before,

    // COMPATIBILITY 2026-08-10 (v1.9.0): Apps predating stored transcript images omit attachmentDelivery and require inline payloads. Remove @Default after the minimum supported app sends this field.
    @Default(MessageAttachmentDelivery.inline) MessageAttachmentDelivery attachmentDelivery,
  }) = _SessionMessagesRequest;

  factory fromJson(Map<String, dynamic> json) => _$SessionMessagesRequestFromJson(json);
}
