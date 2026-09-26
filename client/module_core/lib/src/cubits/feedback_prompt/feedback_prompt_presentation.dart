import "package:freezed_annotation/freezed_annotation.dart";

part "feedback_prompt_presentation.freezed.dart";

/// Whether the app-root presenter should open the rating sheet by itself.
///
/// [FeedbackPromptShow.sequence] increases with every showing so each one is a
/// distinct state for listeners comparing states.
@Freezed()
sealed class FeedbackPromptPresentation with _$FeedbackPromptPresentation {
  const factory idle() = FeedbackPromptIdle;

  const factory show({required int sequence}) = FeedbackPromptShow;
}
