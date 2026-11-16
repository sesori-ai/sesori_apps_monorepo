import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

import "transcript_turns.dart";

/// Where a handoff's summary request stands in the source session.
enum TranscriptHandoffMarkerStatus() {
  /// The agent is still writing the summary.
  writing,

  /// The summary was written and handed to the target.
  sent,

  /// The send did not complete, so the target got nothing.
  notSent,
}

/// The one-line row a summary request's turn folds into in the source session:
/// Sesori's request and the agent's reply never show as messages.
@immutable
final class const TranscriptHandoffMarker({
  required final String targetSessionId,

  /// The target's title when the send started; null when it had none.
  required final String? targetTitle,
  required final TranscriptHandoffMarkerStatus status,

  /// The agent's reply to the request, read as the bridge reads the summary:
  /// its text up to the next user message. Null while it has written none.
  required final String? summary,
});

/// The card that takes the place of a handoff prompt's bubble in the target
/// session.
@immutable
final class const TranscriptHandoffCard({
  required final String sourceSessionId,

  /// The source's title when the send started; null when it had none.
  required final String? sourceTitle,
  required final String summary,

  /// Where the bridge saved the source's transcript for the target's agent.
  required final String transcriptPath,
});

/// The handoffs among the rendered messages.
@immutable
final class const TranscriptHandoffs({
  /// Markers by the id of the summary request they replace, whose row shows
  /// them.
  required final Map<String, TranscriptHandoffMarker> markers,

  /// The messages a marker folds away: everything after its request in the
  /// request's turn, steered follow-ups included.
  required final Set<String> foldedMessageIds,

  /// Cards by the id of the handoff prompt they replace.
  required final Map<String, TranscriptHandoffCard> cards,
}) {
  /// Whether the newest turn is a summary still being written, which its
  /// marker already shows, so no working row joins it. Only the newest turn
  /// is ever writing.
  bool get writing => markers.values.any((marker) => marker.status == TranscriptHandoffMarkerStatus.writing);
}

/// Folds handoff turns into markers and turns handoff prompts into cards.
///
/// Pure and stateless like [TranscriptTurnBuilder], over the same messages and
/// turns, so the widgets hold no folding rule.
class const TranscriptHandoffBuilder() {
  TranscriptHandoffs build({
    required List<MessageWithParts> messages,

    /// [TranscriptTurnBuilder]'s turns for [messages].
    required TranscriptTurns turns,

    /// Whether the session works, so a summary request in the newest turn is
    /// still being answered.
    required bool isBusy,
  }) {
    final byId = {for (final message in messages) message.info.id: message};
    final markers = <String, TranscriptHandoffMarker>{};
    final folded = <String>{};
    for (final (turnIndex, turn) in turns.turns.indexed) {
      final turnMessages = [
        for (final id in turn.messageIds) ?byId[id],
      ];
      // A request is normally its turn's opener, but one the shared turn rule
      // reads as a follow-up folds from where it is all the same.
      final requestIndex = turnMessages.indexWhere(
        (message) => switch (message.info) {
          MessageUser(handoff: MessageHandoffSent() || MessageHandoffNotSent()) => true,
          MessageUser() || MessageAssistant() || MessageError() => false,
        },
      );
      if (requestIndex < 0) continue;
      final request = turnMessages[requestIndex];
      final rest = turnMessages.skip(requestIndex + 1);
      // A prompt steered into a summary being written folds with it, but once
      // a send has stopped, the shared turn rule can join the user's next,
      // ordinary prompt to an unanswered request, so only the reply folds.
      final folds = switch (request.info) {
        MessageUser(handoff: MessageHandoffNotSent()) => rest.takeWhile((message) => message.info is! MessageUser),
        MessageUser() || MessageAssistant() || MessageError() => rest,
      };
      folded.addAll([for (final message in folds) message.info.id]);
      final reply = rest.takeWhile((message) => message.info is! MessageUser).toList();
      final newest = turnIndex == turns.turns.length - 1;
      final marker = switch (request.info) {
        MessageUser(handoff: MessageHandoffSent(:final targetSessionId, :final targetTitle)) => TranscriptHandoffMarker(
          targetSessionId: targetSessionId,
          targetTitle: targetTitle,
          status: newest && isBusy ? TranscriptHandoffMarkerStatus.writing : TranscriptHandoffMarkerStatus.sent,
          summary: _summaryOf(reply: reply),
        ),
        MessageUser(handoff: MessageHandoffNotSent(:final targetSessionId, :final targetTitle)) =>
          TranscriptHandoffMarker(
            targetSessionId: targetSessionId,
            targetTitle: targetTitle,
            status: TranscriptHandoffMarkerStatus.notSent,
            summary: _summaryOf(reply: reply),
          ),
        MessageUser() || MessageAssistant() || MessageError() => null,
      };
      if (marker == null) continue;
      markers[request.info.id] = marker;
    }
    final cards = <String, TranscriptHandoffCard>{
      for (final message in messages)
        if (message.info
            case MessageUser(
              :final id,
              handoff: MessageHandoffReceived(
                :final sourceSessionId,
                :final sourceTitle,
                :final summary,
                :final transcriptPath,
              ),
            )
            when !folded.contains(id))
          id: TranscriptHandoffCard(
            sourceSessionId: sourceSessionId,
            sourceTitle: sourceTitle,
            summary: summary,
            transcriptPath: transcriptPath,
          ),
    };
    return TranscriptHandoffs(
      markers: Map.unmodifiable(markers),
      foldedMessageIds: Set.unmodifiable(folded),
      cards: Map.unmodifiable(cards),
    );
  }

  /// The agent's text in [reply], which runs up to the next user message, as
  /// the bridge's send reads the summary it hands off.
  static String? _summaryOf({required List<MessageWithParts> reply}) {
    final text = [
      for (final message in reply)
        if (message.info case MessageAssistant(sender: MessageSender.agent))
          for (final part in message.parts)
            if (part case MessagePartText(:final text) when text.trim().isNotEmpty) text.trim(),
    ].join("\n\n");
    return text.isEmpty ? null : text;
  }
}
