// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'omp_compaction_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OmpCompactionStartDto _$OmpCompactionStartDtoFromJson(Map json) =>
    _OmpCompactionStartDto(sessionId: json['sessionId'] as String);

_OmpCompactionEndDto _$OmpCompactionEndDtoFromJson(Map json) =>
    _OmpCompactionEndDto(
      sessionId: json['sessionId'] as String,
      aborted: json['aborted'] as bool?,
      skipped: json['skipped'] as bool?,
      errorMessage: json['errorMessage'] as String?,
    );
