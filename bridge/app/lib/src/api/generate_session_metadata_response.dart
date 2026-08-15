import "package:freezed_annotation/freezed_annotation.dart";

part "generate_session_metadata_response.freezed.dart";
part "generate_session_metadata_response.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class GenerateSessionMetadataResponse with _$GenerateSessionMetadataResponse {
  const factory({required String title}) = _GenerateSessionMetadataResponse;

  factory fromJson(Map<String, dynamic> json) => _$GenerateSessionMetadataResponseFromJson(json);
}
