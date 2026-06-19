// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bridges_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BridgesListResponse _$BridgesListResponseFromJson(Map json) =>
    _BridgesListResponse(
      bridges: (json['bridges'] as List<dynamic>)
          .map(
            (e) => BridgeSummary.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
