import 'package:freezed_annotation/freezed_annotation.dart';

part 'open_code_ownership_record.freezed.dart';
part 'open_code_ownership_record.g.dart';

enum OpenCodeOwnershipStatus {
  starting,
  ready,
  stopping,
}

@freezed
sealed class OpenCodeOwnershipRecord with _$OpenCodeOwnershipRecord {
  const factory OpenCodeOwnershipRecord({
    required String ownerSessionId,
    required int openCodePid,
    required String? openCodeStartMarker,
    required String openCodeExecutablePath,
    required String openCodeCommand,
    required List<String> openCodeArgs,
    required int port,
    required int bridgePid,
    required String? bridgeStartMarker,
    required DateTime startedAt,
    required OpenCodeOwnershipStatus status,
  }) = _OpenCodeOwnershipRecord;

  factory OpenCodeOwnershipRecord.fromJson(Map<String, dynamic> json) =>
      _$OpenCodeOwnershipRecordFromJson(json);
}
