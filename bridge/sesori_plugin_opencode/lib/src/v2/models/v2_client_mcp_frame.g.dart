// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'v2_client_mcp_frame.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_V2ClientMcpFrame _$V2ClientMcpFrameFromJson(Map json) => _V2ClientMcpFrame(
  id: json['id'],
  method: _textOrNull(json['method']),
  params: json['params'] == null
      ? null
      : V2ClientMcpParams.fromJson(
          Map<String, dynamic>.from(json['params'] as Map),
        ),
);

_V2ClientMcpParams _$V2ClientMcpParamsFromJson(Map json) => _V2ClientMcpParams(
  meta: json['_meta'] == null
      ? null
      : V2ClientMcpMeta.fromJson(
          Map<String, dynamic>.from(json['_meta'] as Map),
        ),
);

_V2ClientMcpMeta _$V2ClientMcpMetaFromJson(Map json) =>
    _V2ClientMcpMeta(sessionId: _textOrNull(json['ai.opencode/sessionID']));
