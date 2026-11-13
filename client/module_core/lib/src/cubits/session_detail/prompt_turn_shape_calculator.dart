import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/models/composer/new_session_submission_snapshot.dart";
import "../../foundation/models/composer/queued_session_submission.dart";
import "prompt_turn_shape.dart";

/// Decides whether a user turn is an invocation card or a bubble.
///
/// A confirmed turn is a card when the bridge named its invocation. A turn not
/// confirmed yet is a card only when the session's plugin names its command
/// invocations, so the confirmed turn will be a card too and nothing changes
/// shape on the way. The text is never parsed for a `/name`.
class const PromptTurnShapeCalculator() {
  PromptTurnShape ofMessage({required MessageUser message}) => switch (message.invocation) {
    CommandInvocation(:final name, :final source, :final arguments) => PromptTurnShape.invocation(
      name: name,
      source: source,
      arguments: arguments,
    ),
    null => const PromptTurnShape.bubble(),
  };

  /// The bridge gives a queued command a source only when it sent it and will
  /// name its turn, so one without a source stays a bubble to the end.
  PromptTurnShape ofQueuedPrompt({required QueuedSessionPrompt prompt, required bool namesCommandInvocations}) =>
      switch (prompt.commandSource) {
        null => const PromptTurnShape.bubble(),
        final source => _pending(
          command: prompt.command,
          source: source,
          text: prompt.text,
          namesCommandInvocations: namesCommandInvocations,
        ),
      };

  PromptTurnShape ofSubmission({required QueuedSessionSubmission submission, required bool namesCommandInvocations}) =>
      switch (submission) {
        QueuedTextSubmission() => const PromptTurnShape.bubble(),
        QueuedCommandSubmission(:final command, :final commandSource, :final text) ||
        UnavailableQueuedCommandSubmission(:final command, :final commandSource, :final text) => _pending(
          command: command,
          source: commandSource,
          text: text,
          namesCommandInvocations: namesCommandInvocations,
        ),
      };

  PromptTurnShape ofLaunchSubmission({
    required NewSessionSubmissionSnapshot submission,
    required bool namesCommandInvocations,
  }) => switch (submission) {
    NewSessionTextSubmissionSnapshot() => const PromptTurnShape.bubble(),
    NewSessionCommandSubmissionSnapshot(:final command, :final commandSource, :final draft) => _pending(
      command: command,
      source: commandSource,
      text: draft.text,
      namesCommandInvocations: namesCommandInvocations,
    ),
  };

  /// Every user turn a state renders: the launch's first message, the
  /// confirmed messages, the bridge-queued prompts and this surface's own
  /// submissions.
  PromptTurnShapes shapes({
    required bool namesCommandInvocations,
    required NewSessionSubmissionSnapshot? launch,
    required List<MessageWithParts> messages,
    required List<QueuedSessionPrompt> bridgeQueuedPrompts,
    required Iterable<QueuedSessionSubmission> submissions,
  }) => PromptTurnShapes(
    launch: launch == null
        ? const PromptTurnShape.bubble()
        : ofLaunchSubmission(submission: launch, namesCommandInvocations: namesCommandInvocations),
    messages: {
      for (final MessageWithParts(:info) in messages)
        if (info case final MessageUser user)
          if (ofMessage(message: user) case final InvocationPromptTurnShape shape) user.id: shape,
    },
    prompts: {
      for (final submission in submissions)
        if (ofSubmission(submission: submission, namesCommandInvocations: namesCommandInvocations)
            case final InvocationPromptTurnShape shape)
          submission.promptId: shape,
      for (final prompt in bridgeQueuedPrompts)
        if (ofQueuedPrompt(prompt: prompt, namesCommandInvocations: namesCommandInvocations)
            case final InvocationPromptTurnShape shape)
          prompt.id: shape,
    },
  );

  /// A command not confirmed yet. It is a card when the plugin names
  /// invocations, so the confirmed turn comes back as a card too. A command
  /// without a known source is "Custom" from the start, as the bridge names it.
  PromptTurnShape _pending({
    required String? command,
    required CommandSource? source,
    required String? text,
    required bool namesCommandInvocations,
  }) {
    if (!namesCommandInvocations || command == null) return const PromptTurnShape.bubble();
    final arguments = text?.trim();
    return PromptTurnShape.invocation(
      name: command,
      source: source ?? CommandSource.unknown,
      arguments: arguments == null || arguments.isEmpty ? null : arguments,
    );
  }
}
