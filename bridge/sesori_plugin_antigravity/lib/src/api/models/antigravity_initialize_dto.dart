import "package:freezed_annotation/freezed_annotation.dart";

part "antigravity_initialize_dto.freezed.dart";
part "antigravity_initialize_dto.g.dart";

const _dtoOptions = Freezed(
  fromJson: true,
  toJson: false,
  copyWith: false,
  equal: false,
  toStringOverride: false,
);

/// Released `initialize` fields used by the Antigravity runtime contract probe.
@_dtoOptions
sealed class AntigravityInitializeDto with _$AntigravityInitializeDto {
  const factory({
    required int? protocolVersion,
    required AntigravityAgentInfoDto? agentInfo,
    required AntigravityAgentCapabilitiesDto? agentCapabilities,
    required List<AntigravityAuthMethodDto>? authMethods,
  }) = _AntigravityInitializeDto;

  factory fromJson(Map<String, dynamic> json) => _$AntigravityInitializeDtoFromJson(json);
}

@_dtoOptions
sealed class AntigravityAgentInfoDto with _$AntigravityAgentInfoDto {
  const factory({
    required String? name,
    required String? title,
    required String? version,
  }) = _AntigravityAgentInfoDto;

  factory fromJson(Map<String, dynamic> json) => _$AntigravityAgentInfoDtoFromJson(json);
}

@_dtoOptions
sealed class AntigravityAgentCapabilitiesDto with _$AntigravityAgentCapabilitiesDto {
  const factory({
    required bool? loadSession,
    required AntigravitySessionCapabilitiesDto? sessionCapabilities,
    required AntigravityAuthCapabilitiesDto? auth,
  }) = _AntigravityAgentCapabilitiesDto;

  factory fromJson(Map<String, dynamic> json) => _$AntigravityAgentCapabilitiesDtoFromJson(json);
}

@_dtoOptions
sealed class AntigravitySessionCapabilitiesDto with _$AntigravitySessionCapabilitiesDto {
  const factory({
    @AntigravityCapabilityPresenceConverter() required bool list,
    @AntigravityCapabilityPresenceConverter() required bool resume,
    @AntigravityCapabilityPresenceConverter() required bool close,
  }) = _AntigravitySessionCapabilitiesDto;

  factory fromJson(Map<String, dynamic> json) => _$AntigravitySessionCapabilitiesDtoFromJson(json);
}

@_dtoOptions
sealed class AntigravityAuthCapabilitiesDto with _$AntigravityAuthCapabilitiesDto {
  const factory({
    @AntigravityCapabilityPresenceConverter() required bool logout,
  }) = _AntigravityAuthCapabilitiesDto;

  factory fromJson(Map<String, dynamic> json) => _$AntigravityAuthCapabilitiesDtoFromJson(json);
}

@_dtoOptions
sealed class AntigravityAuthMethodDto with _$AntigravityAuthMethodDto {
  const factory({required String? id}) = _AntigravityAuthMethodDto;

  factory fromJson(Map<String, dynamic> json) => _$AntigravityAuthMethodDtoFromJson(json);
}

/// ACP capability markers are advertised as objects; explicit `false` and
/// omission both mean unsupported.
// ignore: no_slop_linter/prefer_specific_type, ACP capability markers are object-or-false wire values
class const AntigravityCapabilityPresenceConverter() implements JsonConverter<bool, Object?> {
  @override
  bool fromJson(Object? json) => switch (json) {
    null || false => false,
    true || Map<Object?, Object?>() => true,
    _ => throw const FormatException("invalid ACP capability marker"),
  };

  @override
  Object? toJson(bool object) => object ? const <String, dynamic>{} : null;
}
