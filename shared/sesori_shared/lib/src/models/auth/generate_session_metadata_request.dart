import "package:freezed_annotation/freezed_annotation.dart";

part "generate_session_metadata_request.freezed.dart";
part "generate_session_metadata_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class GenerateSessionMetadataRequest with _$GenerateSessionMetadataRequest {
  const factory({required String firstMessage}) = _GenerateSessionMetadataRequest;

  factory fromJson(Map<String, dynamic> json) => _$GenerateSessionMetadataRequestFromJson(json);
}
