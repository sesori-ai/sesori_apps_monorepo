import "package:freezed_annotation/freezed_annotation.dart";

part "antigravity_permission_response_dto.freezed.dart";
part "antigravity_permission_response_dto.g.dart";

const _output = Freezed(copyWith: false, equal: false, toStringOverride: false, fromJson: false, toJson: true);

@_output
sealed class AntigravityPermissionResponseDto with _$AntigravityPermissionResponseDto {
  const factory({required AntigravityPermissionOutcomeDto outcome}) = _AntigravityPermissionResponseDto;
}

@Freezed(
  unionKey: "outcome",
  copyWith: false,
  equal: false,
  toStringOverride: false,
  fromJson: false,
  toJson: true,
)
sealed class AntigravityPermissionOutcomeDto with _$AntigravityPermissionOutcomeDto {
  const factory selected({required String optionId}) = AntigravityPermissionSelectedDto;
  const factory cancelled() = AntigravityPermissionCancelledDto;
}
