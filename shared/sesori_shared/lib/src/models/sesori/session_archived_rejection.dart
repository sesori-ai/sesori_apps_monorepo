import "package:freezed_annotation/freezed_annotation.dart";

part "session_archived_rejection.freezed.dart";

part "session_archived_rejection.g.dart";

/// Why a mutation against an archived session was refused.
enum SessionArchivedReason() {
  @JsonValue("archived_read_only")
  archivedReadOnly,
}

/// The 409 body returned for every mutation refused because the target session
/// is archived. Archiving is permanent: archived sessions are audit-only.
@Freezed(fromJson: true, toJson: true)
sealed class SessionArchivedRejection with _$SessionArchivedRejection {
  const factory({
    required String sessionId,
    required SessionArchivedReason reason,
  }) = _SessionArchivedRejection;

  factory fromJson(Map<String, dynamic> json) => _$SessionArchivedRejectionFromJson(json);
}
