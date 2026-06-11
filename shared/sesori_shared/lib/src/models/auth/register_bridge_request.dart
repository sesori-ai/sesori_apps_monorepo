import "package:freezed_annotation/freezed_annotation.dart";

part "register_bridge_request.freezed.dart";
part "register_bridge_request.g.dart";

/// Request body for `POST /auth/bridges`.
///
/// When [bridgeId] is null the key is omitted from the JSON body and the
/// server mints a fresh bridge id; when set, the server updates the existing
/// registration with that id.
@Freezed(fromJson: true, toJson: true)
sealed class RegisterBridgeRequest with _$RegisterBridgeRequest {
  const factory RegisterBridgeRequest({
    required String name,
    required String platform,
    @JsonKey(includeIfNull: false) required String? bridgeId,
  }) = _RegisterBridgeRequest;

  factory RegisterBridgeRequest.fromJson(Map<String, dynamic> json) => _$RegisterBridgeRequestFromJson(json);
}
