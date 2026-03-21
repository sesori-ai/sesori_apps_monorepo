import "package:freezed_annotation/freezed_annotation.dart";

part "update_session_archive_request.freezed.dart";

part "update_session_archive_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class UpdateSessionArchiveRequest with _$UpdateSessionArchiveRequest {
  const factory UpdateSessionArchiveRequest({
    @JsonKey(required: true) required UpdateSessionArchiveTime time,
  }) = _UpdateSessionArchiveRequest;

  factory UpdateSessionArchiveRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateSessionArchiveRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class UpdateSessionArchiveTime with _$UpdateSessionArchiveTime {
  const factory UpdateSessionArchiveTime({
    @JsonKey(required: true) required int? archived,
  }) = _UpdateSessionArchiveTime;

  factory UpdateSessionArchiveTime.fromJson(Map<String, dynamic> json) => _$UpdateSessionArchiveTimeFromJson(json);
}
