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
    @JsonKey(name: "oauth", fromJson: _oauthEnabled) required bool oauthEnabled,
  }) = _OpenCodeMcpServerConfigurationDto;
  factory fromJson(Map<String, dynamic> json) => _$OpenCodeMcpServerConfigurationDtoFromJson(json);
}

bool _oauthEnabled(Object? value) => switch (value) {
  null || Map() => true,
  false => false,
  _ => throw const FormatException("Unsupported native MCP OAuth configuration"),
};

/// Native empty authorizationUrl is decoded here, then mapped to a domain variant.
@Freezed(copyWith: false, toJson: false, equal: false, toStringOverride: false)
sealed class OpenCodeMcpAuthenticationResponseDto with _$OpenCodeMcpAuthenticationResponseDto {
  const factory({required String authorizationUrl, required String oauthState}) = _OpenCodeMcpAuthenticationResponseDto;
  factory fromJson(Map<String, dynamic> json) => _$OpenCodeMcpAuthenticationResponseDtoFromJson(json);
}
