import "package:freezed_annotation/freezed_annotation.dart";

import "session.dart";

part "session_page.freezed.dart";
part "session_page.g.dart";

/// Which sessions a page lists: the live ones or the archived ones.
@JsonEnum()
enum SessionPageMode() {
  active,
  archived,
}

/// The session list chip a page is narrowed by.
@JsonEnum()
enum SessionPageFilter() {
  all,
  running,
  unread,
}

/// The body of `POST /sessions/page`: one page of root sessions across the
/// bridge's visible projects, newest first.
@Freezed(fromJson: true, toJson: true, copyWith: false)
sealed class SessionPageRequest with _$SessionPageRequest {
  const factory({
    required SessionPageMode mode,

    /// Null lists every visible project.
    required String? projectId,

    /// Null means no search; a query must hold at least one word.
    required String? query,
    required SessionPageFilter filter,

    /// The previous page's [SessionPageResponse.nextCursor]; null for the
    /// first page.
    required String? cursor,

    /// From 0 to 1000. Zero asks for the counts only.
    required int limit,
  }) = _SessionPageRequest;

  factory fromJson(Map<String, dynamic> json) => _$SessionPageRequestFromJson(json);
}

/// One page of root sessions in display order, and the counts behind the
/// chips.
@Freezed(fromJson: true, toJson: true, copyWith: false)
sealed class SessionPageResponse with _$SessionPageResponse {
  const factory({
    required List<Session> items,

    /// Null when no rows follow this page, and for a counts-only request.
    required String? nextCursor,
    required SessionPageCounts counts,
  }) = _SessionPageResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionPageResponseFromJson(json);
}

/// How many sessions each chip holds under the request's mode, project and
/// query, whatever chip the request itself asked for.
@Freezed(fromJson: true, toJson: true, copyWith: false)
sealed class SessionPageCounts with _$SessionPageCounts {
  const factory({
    required int all,
    required int running,
    required int unread,
  }) = _SessionPageCounts;

  factory fromJson(Map<String, dynamic> json) => _$SessionPageCountsFromJson(json);
}
