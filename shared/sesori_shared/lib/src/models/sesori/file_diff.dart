import "package:freezed_annotation/freezed_annotation.dart";

part "file_diff.freezed.dart";

part "file_diff.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class FileDiff with _$FileDiff {
  const factory FileDiff.content({
    required String file,
    required String before,
    required String after,
    required int additions,
    required int deletions,
    required FileDiffStatus? status,
  }) = FileDiffContent;

  const factory FileDiff.skipped({
    required String file,
    required FileDiffSkipReason reason,
    required FileDiffStatus? status,
  }) = FileDiffSkipped;

  factory FileDiff.fromJson(Map<String, dynamic> json) => _$FileDiffFromJson(json);
}

@JsonEnum(alwaysCreate: true)
enum FileDiffStatus {
  added,
  deleted,
  modified,
}

@JsonEnum(alwaysCreate: true)
enum FileDiffSkipReason {
  binary,
  tooLarge,
  readError,
}
