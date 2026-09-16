// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_approval_details_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexApprovalDetailsDto _$CodexApprovalDetailsDtoFromJson(Map json) =>
    _CodexApprovalDetailsDto(
      command: json['command'] as String?,
      itemId: json['itemId'] as String?,
      networkApprovalContext: json['networkApprovalContext'] == null
          ? null
          : CodexNetworkApprovalContextDto.fromJson(
              Map<String, dynamic>.from(json['networkApprovalContext'] as Map),
            ),
    );

_CodexNetworkApprovalContextDto _$CodexNetworkApprovalContextDtoFromJson(
  Map json,
) => _CodexNetworkApprovalContextDto(host: json['host'] as String);
