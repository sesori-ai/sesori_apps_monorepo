import "package:freezed_annotation/freezed_annotation.dart";

part "generate_session_metadata_request.freezed.dart";
part "generate_session_metadata_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class GenerateSessionMetadataRequest with _$GenerateSessionMetadataRequest {
  const factory({
    required String firstMessage,

    /// Attributes the session to this computer for per-platform activation
    /// analytics. Null before the bridge has registered.
    required String? bridgeId,
  }) = _GenerateSessionMetadataRequest;

  factory fromJson(Map<String, dynamic> json) => _$GenerateSessionMetadataRequestFromJson(json);
}
