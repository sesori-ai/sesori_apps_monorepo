import "package:freezed_annotation/freezed_annotation.dart";

part "question.freezed.dart";

part "question.g.dart";

/// Non-question native requests have a cancel-only notice for released clients.
enum QuestionInteractionKind() {
  question,
  form,
  externalAction,
  unknown,
}

/// A single question within a [QuestionRequest], containing the prompt text,
/// available options, and selection mode.
@Freezed(fromJson: true, toJson: true)
sealed class QuestionInfo with _$QuestionInfo {
  const factory({
    required String question,
    required String header,
    @Default([]) List<QuestionOption> options,
    @Default(false) bool multiple,
    @Default(true) bool custom,
  }) = _QuestionInfo;

  factory fromJson(Map<String, dynamic> json) => _$QuestionInfoFromJson(json);
}

/// A selectable choice for a question.
@Freezed(fromJson: true, toJson: true)
sealed class QuestionOption with _$QuestionOption {
  const factory({
    required String label,
    required String description,

    /// Whether the harness marks this option as its default answer; the client
    /// shows it selected when the question arrives.
    // COMPATIBILITY 2026-11-12 (v1.13.0): bridges before default answers omit
    // this field; false keeps their questions unselected. Remove the default
    // once no supported bridge omits the field.
    @Default(false) bool isDefault,
  }) = _QuestionOption;

  factory fromJson(Map<String, dynamic> json) => _$QuestionOptionFromJson(json);
}
