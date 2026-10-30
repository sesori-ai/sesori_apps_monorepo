import "package:freezed_annotation/freezed_annotation.dart";

import "../sesori/health_response.dart" show BridgeKind;

part "register_bridge_request.freezed.dart";
part "register_bridge_request.g.dart";

/// Request body for `POST /auth/bridges`.
///
/// When [bridgeId] is null the key is omitted from the JSON body and the
/// server mints a fresh bridge id; when set, the server updates the existing
/// registration with that id.
///
/// [hostKey] is a salted hash of the computer's machine identifier, so a
/// reinstall that lost its stored [bridgeId] reuses the computer's existing
/// registration. It is omitted when the identifier could not be read.
///
/// [kind] tells the auth server whether Sesori Desktop or the standalone CLI
/// runs this bridge, for per-platform activation analytics.
@Freezed(fromJson: true, toJson: true)
sealed class RegisterBridgeRequest with _$RegisterBridgeRequest {
  const factory({
    required String name,
    required String platform,
    @JsonKey(includeIfNull: false) required String? bridgeId,
    required String? hostKey,
    required BridgeKind kind,
  }) = _RegisterBridgeRequest;

  factory fromJson(Map<String, dynamic> json) => _$RegisterBridgeRequestFromJson(json);
}
