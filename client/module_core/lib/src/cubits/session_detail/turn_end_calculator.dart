import "package:sesori_shared/sesori_shared.dart";

import "interrupted_turn.dart";

/// Decides how the transcript ends the turn a bridge stop cut off: where the
/// Interrupted line goes, which Stopped lines it replaces, and whether it
/// offers Continue.
///
/// Pure and stateless like `PromptTurnShapeCalculator`; the cubit keeps its
/// result on the loaded state, so widgets only render it.
class const TurnEndCalculator() {
  InterruptedTurnView interruptedTurn({
    required List<MessageWithParts> messages,
    required SessionInterruption? interruption,
    required SessionStatus sessionStatus,

    /// Whether a prompt is on its way: sending, failed, queued here or on
    /// the bridge, or a launch follow-up not yet answered.
    required bool hasPendingPrompts,
  }) {
    if (interruption == null) return const InterruptedTurnView.absent();
    final afterMessageId = interruption.afterMessageId;
    final turns = splitPromptTurns(messages: messages, turnEndMessageIds: {afterMessageId});
    final index = turns.indexWhere((turn) => turn.messages.any((message) => message.info.id == afterMessageId));
    if (index == -1) return const InterruptedTurnView.absent();
    final turn = turns[index];
    return InterruptedTurnView.shown(
      afterMessageId: afterMessageId,
      lineAfterMessageId: turn.messages.last.info.id,
      supersededStoppedIds: {
        for (final message in turn.messages)
          if (message.info case MessageError(kind: MessageErrorKind.stopped, :final id)) id,
      },
      continueRefusal: switch ((index == turns.length - 1, sessionStatus, hasPendingPrompts)) {
        (false, _, _) => InterruptedTurnContinueRefusal.laterTurn,
        (true, SessionStatusBusy() || SessionStatusRetry(), _) => InterruptedTurnContinueRefusal.sessionWorking,
        (true, SessionStatusIdle(), true) => InterruptedTurnContinueRefusal.promptPending,
        (true, SessionStatusIdle(), false) => null,
      },
    );
  }
}
