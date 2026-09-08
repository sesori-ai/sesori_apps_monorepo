import "package:freezed_annotation/freezed_annotation.dart";

part "antigravity_session_metadata_dto.freezed.dart";
part "antigravity_session_metadata_dto.g.dart";

/// The only private metadata field consumed; unknown fields are ignored.
@Freezed(copyWith: false, equal: false, toStringOverride: false, toJson: false)
sealed class AntigravitySessionMetadataDto with _$AntigravitySessionMetadataDto {
  const factory({required String cwd}) = _AntigravitySessionMetadataDto;
  factory fromJson(Map<String, dynamic> json) => _$AntigravitySessionMetadataDtoFromJson(json);
}
