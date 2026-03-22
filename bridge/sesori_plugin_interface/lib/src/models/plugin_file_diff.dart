import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_file_diff.freezed.dart";

part "plugin_file_diff.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class PluginFileDiff with _$PluginFileDiff {
  const factory PluginFileDiff({
    required String file,
    required String before,
    required String after,
    required int additions,
    required int deletions,
    String? status,
  }) = _PluginFileDiff;

  factory PluginFileDiff.fromJson(Map<String, dynamic> json) => _$PluginFileDiffFromJson(json);
}
