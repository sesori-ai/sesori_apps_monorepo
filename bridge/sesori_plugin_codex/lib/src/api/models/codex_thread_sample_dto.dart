import "package:freezed_annotation/freezed_annotation.dart";

part "codex_thread_sample_dto.freezed.dart";
part "codex_thread_sample_dto.g.dart";

/// The `thread/sample` response: one model reply on a throwaway copy of the
/// thread, which Codex deletes afterwards.
@Freezed(fromJson: true, toJson: false)
sealed class CodexThreadSampleDto with _$CodexThreadSampleDto {
  const factory({
    /// The reply text; null when the model tried a tool call or gave no text.
    required String? text,
  }) = _CodexThreadSampleDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexThreadSampleDtoFromJson(json);
}
