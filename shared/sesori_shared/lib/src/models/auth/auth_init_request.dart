import "package:freezed_annotation/freezed_annotation.dart";

part "auth_init_request.freezed.dart";
part "auth_init_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class AuthInitRequest with _$AuthInitRequest {
  const factory AuthInitRequest({
    required String clientType,
  }) = _AuthInitRequest;

  factory AuthInitRequest.fromJson(Map<String, dynamic> json) => _$AuthInitRequestFromJson(json);
}
