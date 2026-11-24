// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gh_graphql_response_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GhGraphQlResponseDto _$GhGraphQlResponseDtoFromJson(Map json) => _GhGraphQlResponseDto(
  data: (json['data'] as Map?)?.map((k, e) => MapEntry(k as String, e)),
  errors:
      (json['errors'] as List<dynamic>?)
          ?.map(
            (e) => GhGraphQlErrorDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList() ??
      const <GhGraphQlErrorDto>[],
);

_GhGraphQlErrorDto _$GhGraphQlErrorDtoFromJson(Map json) => _GhGraphQlErrorDto(message: json['message'] as String?);
