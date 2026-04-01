// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_diffs_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionDiffsResponse _$SessionDiffsResponseFromJson(Map json) =>
    _SessionDiffsResponse(
      diffs: (json['diffs'] as List<dynamic>)
          .map((e) => FileDiff.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );

Map<String, dynamic> _$SessionDiffsResponseToJson(
  _SessionDiffsResponse instance,
) => <String, dynamic>{'diffs': instance.diffs.map((e) => e.toJson()).toList()};
