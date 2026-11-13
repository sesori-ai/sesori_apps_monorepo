import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "prompt_turn_shape.freezed.dart";

/// How a user turn renders in the transcript, as `PromptTurnShapeCalculator`
/// resolves it.
@Freezed()
sealed class PromptTurnShape with _$PromptTurnShape {
  /// A command, skill or MCP prompt the user ran: an event card naming [name]
  /// and its [source], over the [arguments] they typed, or none.
  const factory invocation({
    required String name,
    required CommandSource source,
    required String? arguments,
  }) = InvocationPromptTurnShape;

  /// An ordinary chat bubble.
  const factory bubble() = BubblePromptTurnShape;
}

/// The resolved shape of every user turn a state renders. A turn missing from
/// [messages] or [prompts] is a bubble, so only invocations are listed.
@Freezed()
sealed class const PromptTurnShapes._() with _$PromptTurnShapes {
  const factory({
    /// The launch's first message, while the state shows it.
    @Default(PromptTurnShape.bubble()) PromptTurnShape launch,

    /// Confirmed user messages, by message id.
    @Default({}) Map<String, InvocationPromptTurnShape> messages,

    /// Prompts the transcript does not hold yet, by prompt id: local
    /// submissions, launch follow-ups and bridge-queued prompts.
    @Default({}) Map<String, InvocationPromptTurnShape> prompts,
  }) = _PromptTurnShapes;

  PromptTurnShape ofMessage({required String messageId}) => messages[messageId] ?? const PromptTurnShape.bubble();

  PromptTurnShape ofPrompt({required String promptId}) => prompts[promptId] ?? const PromptTurnShape.bubble();
}
