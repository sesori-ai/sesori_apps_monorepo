import "package:freezed_annotation/freezed_annotation.dart";

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
  }) = _SessionListRequest;

  factory SessionListRequest.fromJson(Map<String, dynamic> json) => _$SessionListRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class Session with _$Session {
  const factory Session({
    required String id,
    required String projectID,
    required String directory,
    required String? parentID,
    required String? title,
    required SessionTime? time,
    required SessionSummary? summary,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);
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

@Freezed(fromJson: true, toJson: true)
sealed class SessionSummary with _$SessionSummary {
  const factory SessionSummary({
    @Default(0) int additions,
    @Default(0) int deletions,
    @Default(0) int files,
  }) = _SessionSummary;

  factory SessionSummary.fromJson(Map<String, dynamic> json) => _$SessionSummaryFromJson(json);
}

/// Session with embedded project info, returned by `/experimental/session`.
///
/// This is the `GlobalInfo` type from the OpenCode server — a [Session] extended
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
    required SessionSummary? summary,
    required SessionProject? project,
  }) = _GlobalSession;

  factory GlobalSession.fromJson(Map<String, dynamic> json) => _$GlobalSessionFromJson(json);
}

/// Lightweight project reference embedded in [GlobalSession].
///
/// This is the `ProjectInfo` / `ProjectSummary` type from the OpenCode server —
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
