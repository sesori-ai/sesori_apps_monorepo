import "package:freezed_annotation/freezed_annotation.dart";

part "open_code_service_registration.freezed.dart";
part "open_code_service_registration.g.dart";

/// OpenCode 2's shared background-service registration (`service.json`):
/// where the service listens, its process id and its private Basic-auth
/// password. OpenCode writes the file with 0600 permissions; the bridge only
/// reads it.
@Freezed(toJson: false)
sealed class OpenCodeServiceRegistration with _$OpenCodeServiceRegistration {
  // ignore: invalid_annotation_target, Freezed forwards this to the generated class.
  @JsonSerializable(checked: true)
  const factory({required String url, required int pid, required String? password}) = _OpenCodeServiceRegistration;

  factory fromJson(Map<String, dynamic> json) => _$OpenCodeServiceRegistrationFromJson(json);
}
