import "package:freezed_annotation/freezed_annotation.dart";

part "file_diff.freezed.dart";

part "file_diff.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class FileDiff with _$FileDiff {
  const factory FileDiff({
    required String file,
    required String patch,
    required int additions,
    required int deletions,
    FileDiffStatus? status,
  }) = _FileDiff;

  factory FileDiff.fromJson(Map<String, dynamic> json) => _$FileDiffFromJson(json);
}

@JsonEnum(alwaysCreate: true)
enum FileDiffStatus {
  added,
  deleted,
  modified,
}
