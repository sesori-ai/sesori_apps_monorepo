import "package:freezed_annotation/freezed_annotation.dart";

part "codex_account_dto.freezed.dart";
part "codex_account_dto.g.dart";

enum CodexAccountLoginType {
  @JsonValue("chatgptDeviceCode")
  chatgptDeviceCode,
}

enum CodexAccountLoginCancelStatus {
  @JsonValue("canceled")
  canceled,
  @JsonValue("notFound")
  notFound,
  unknown,
}

@Freezed(fromJson: false, toJson: true)
sealed class CodexDeviceLoginStartParamsDto with _$CodexDeviceLoginStartParamsDto {
  const factory CodexDeviceLoginStartParamsDto({
    required CodexAccountLoginType type,
  }) = _CodexDeviceLoginStartParamsDto;
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexDeviceLoginStartResponseDto with _$CodexDeviceLoginStartResponseDto {
  const factory CodexDeviceLoginStartResponseDto({
    required CodexAccountLoginType type,
    required String loginId,
    required String verificationUrl,
    required String userCode,
  }) = _CodexDeviceLoginStartResponseDto;

  factory CodexDeviceLoginStartResponseDto.fromJson(
    Map<String, dynamic> json,
  ) => _$CodexDeviceLoginStartResponseDtoFromJson(json);
}

@Freezed(fromJson: false, toJson: true)
sealed class CodexAccountLoginCancelParamsDto with _$CodexAccountLoginCancelParamsDto {
  const factory CodexAccountLoginCancelParamsDto({
    required String loginId,
  }) = _CodexAccountLoginCancelParamsDto;
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexAccountLoginCancelResponseDto with _$CodexAccountLoginCancelResponseDto {
  const factory CodexAccountLoginCancelResponseDto({
    @JsonKey(unknownEnumValue: CodexAccountLoginCancelStatus.unknown) required CodexAccountLoginCancelStatus status,
  }) = _CodexAccountLoginCancelResponseDto;

  factory CodexAccountLoginCancelResponseDto.fromJson(
    Map<String, dynamic> json,
  ) => _$CodexAccountLoginCancelResponseDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexAccountLoginCompletedNotificationDto with _$CodexAccountLoginCompletedNotificationDto {
  const factory CodexAccountLoginCompletedNotificationDto({
    required String? loginId,
    required bool success,
    required String? error,
  }) = _CodexAccountLoginCompletedNotificationDto;

  factory CodexAccountLoginCompletedNotificationDto.fromJson(
    Map<String, dynamic> json,
  ) => _$CodexAccountLoginCompletedNotificationDtoFromJson(json);
}
