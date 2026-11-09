// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_mcp_oauth_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexMcpOAuthLoginDto _$CodexMcpOAuthLoginDtoFromJson(Map json) =>
    _CodexMcpOAuthLoginDto(
      authorizationUrl: json['authorizationUrl'] as String,
    );

_CodexMcpOAuthCompletionDto _$CodexMcpOAuthCompletionDtoFromJson(Map json) =>
    _CodexMcpOAuthCompletionDto(
      name: json['name'] as String,
      success: json['success'] as bool,
      error: json['error'] as String?,
      threadId: json['threadId'] as String?,
    );
