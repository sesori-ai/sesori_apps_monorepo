import "package:freezed_annotation/freezed_annotation.dart";

part "question.freezed.dart";

part "question.g.dart";

/// A single question within a [QuestionRequest], containing the prompt text,
/// available options, and selection mode.
@Freezed(fromJson: true, toJson: true)
sealed class QuestionInfo with _$QuestionInfo {
  const factory QuestionInfo({
    required String question,
    required String header,
    @Default([]) List<QuestionOption> options,
    @Default(false) bool multiple,
    @Default(true) bool custom,
  }) = _QuestionInfo;

  factory QuestionInfo.fromJson(Map<String, dynamic> json) => _$QuestionInfoFromJson(json);
}

/// A selectable choice for a question.
@Freezed(fromJson: true, toJson: true)
sealed class QuestionOption with _$QuestionOption {
  const factory QuestionOption({
    required String label,
    required String description,
  }) = _QuestionOption;

  factory QuestionOption.fromJson(Map<String, dynamic> json) => _$QuestionOptionFromJson(json);
}
