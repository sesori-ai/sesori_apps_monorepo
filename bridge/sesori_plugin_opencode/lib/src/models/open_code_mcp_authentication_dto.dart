import "package:freezed_annotation/freezed_annotation.dart";

part "open_code_mcp_authentication_dto.freezed.dart";
part "open_code_mcp_authentication_dto.g.dart";

enum OpenCodeMcpTransport() {
  local,
  remote,
  unknown,
}

/// Read only the configuration needed for native authentication eligibility.
@Freezed(copyWith: false, toJson: false, equal: false, toStringOverride: false)
sealed class OpenCodeMcpConfigurationDto with _$OpenCodeMcpConfigurationDto {
  const factory({@Default({}) Map<String, OpenCodeMcpServerConfigurationDto> mcp}) = _OpenCodeMcpConfigurationDto;
  factory fromJson(Map<String, dynamic> json) => _$OpenCodeMcpConfigurationDtoFromJson(json);
}

@Freezed(copyWith: false, toJson: false, equal: false, toStringOverride: false)
sealed class OpenCodeMcpServerConfigurationDto with _$OpenCodeMcpServerConfigurationDto {
  const factory({
    @JsonKey(name: "type", unknownEnumValue: OpenCodeMcpTransport.unknown) required OpenCodeMcpTransport? transport,
    required String? url,
    @JsonKey(fromJson: _oauthConfiguration) required OpenCodeMcpOAuthConfiguration oauth,
  }) = _OpenCodeMcpServerConfigurationDto;
  factory fromJson(Map<String, dynamic> json) => _$OpenCodeMcpServerConfigurationDtoFromJson(json);
}

sealed class const OpenCodeMcpOAuthConfiguration();
final class const OpenCodeMcpOAuthDisabled() extends OpenCodeMcpOAuthConfiguration;
final class const OpenCodeMcpOAuthEnabled({required final OpenCodeMcpOAuthParametersDto parameters})
    extends OpenCodeMcpOAuthConfiguration;

@Freezed(copyWith: false, toJson: false, equal: false, toStringOverride: false)
sealed class OpenCodeMcpOAuthParametersDto with _$OpenCodeMcpOAuthParametersDto {
  const factory({required String? redirectUri}) = _OpenCodeMcpOAuthParametersDto;
  factory fromJson(Map<String, dynamic> json) => _$OpenCodeMcpOAuthParametersDtoFromJson(json);
}

OpenCodeMcpOAuthConfiguration _oauthConfiguration(Object? value) => switch (value) {
  null => const OpenCodeMcpOAuthEnabled(parameters: OpenCodeMcpOAuthParametersDto(redirectUri: null)),
  Map() => OpenCodeMcpOAuthEnabled(parameters: OpenCodeMcpOAuthParametersDto.fromJson(value.cast<String, dynamic>())),
  false => const OpenCodeMcpOAuthDisabled(),
  _ => throw const FormatException("Unsupported native MCP OAuth configuration"),
};

/// Native empty authorizationUrl is decoded here, then mapped to a domain variant.
@Freezed(copyWith: false, toJson: false, equal: false, toStringOverride: false)
sealed class OpenCodeMcpAuthenticationResponseDto with _$OpenCodeMcpAuthenticationResponseDto {
  const factory({required String authorizationUrl, required String oauthState}) = _OpenCodeMcpAuthenticationResponseDto;
  factory fromJson(Map<String, dynamic> json) => _$OpenCodeMcpAuthenticationResponseDtoFromJson(json);
}
