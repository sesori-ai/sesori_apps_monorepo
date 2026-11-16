import "package:freezed_annotation/freezed_annotation.dart";

part "interrupted_turn.freezed.dart";

/// How the transcript ends the turn a bridge stop cut off, as
/// `TurnEndCalculator` resolves it from the session's interruption.
@Freezed()
sealed class const InterruptedTurnView._() with _$InterruptedTurnView {
  /// No interruption, or one whose message is not loaded.
  const factory absent() = InterruptedTurnAbsent;

  /// The cut-off turn is loaded: it ends with the Interrupted line.
  const factory shown({
    /// The message the bridge recorded the stop after. The turn ends there, so
    /// a later prompt opens a new turn even when the cut-off one had no reply.
    required String afterMessageId,

    /// The cut-off turn's last loaded message, which the line follows.
    required String lineAfterMessageId,

    /// The cut-off turn's stopped rows. The Interrupted line says how the turn
    /// ended, so they draw no Stopped line of their own.
    required Set<String> supersededStoppedIds,

    /// Why the line offers no Continue, or null while it does.
    required InterruptedTurnContinueRefusal? continueRefusal,
  }) = InterruptedTurnShown;

  /// The messages after which a turn ended without a reply, for
  /// `splitPromptTurns`.
  Set<String> get turnEndMessageIds => switch (this) {
    InterruptedTurnShown(:final afterMessageId) => {afterMessageId},
    InterruptedTurnAbsent() => const {},
  };
}

/// Why Continue cannot pick an interrupted turn back up.
enum InterruptedTurnContinueRefusal() {
  /// The transcript shows no interrupted turn.
  noInterruptedTurn,

  /// A later turn follows the interrupted one.
  laterTurn,

  /// The session is working.
  sessionWorking,

  /// A prompt is waiting to be sent or answered.
  promptPending,
}
