import "package:sesori_dart_core/src/cubits/session_detail/interrupted_turn.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_composer_mode.dart";
import "package:sesori_dart_core/src/cubits/session_detail/turn_end_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

MessageWithParts _prompt({required String id}) => MessageWithParts(
  info: Message.user(invocation: null, handoff: null, id: id, sessionID: "s", agent: null, time: null, promptId: null),
  parts: [MessagePart.text(id: "$id-text", sessionID: "s", messageID: id, text: "Fix the build")],
);

MessageWithParts _reply({required String id}) => MessageWithParts(
  info: Message.assistant(
    id: id,
    sessionID: "s",
    agent: null,
    modelID: null,
    providerID: null,
    sender: MessageSender.agent,
    time: null,
  ),
  parts: [MessagePart.text(id: "$id-text", sessionID: "s", messageID: id, text: "Working on it.")],
);

/// The row Claude Code and Codex record when a bridge stop ends their run,
/// the same as a user's Stop.
MessageWithParts _stopped({required String id}) => MessageWithParts(
  info: Message.error(
    id: id,
    sessionID: "s",
    agent: null,
    modelID: null,
    providerID: null,
    errorName: "aborted",
    errorMessage: "Step interrupted",
    kind: MessageErrorKind.stopped,
    time: null,
  ),
  parts: const [],
);

InterruptedTurnView _view({
  required List<MessageWithParts> messages,
  required String? afterMessageId,
  SessionStatus sessionStatus = const SessionStatus.idle(),
  bool hasPendingPrompts = false,
  SessionEditPhase? editPhase,
}) => const TurnEndCalculator().interruptedTurn(
  messages: messages,
  interruption: afterMessageId == null
      ? null
      : SessionInterruption(afterMessageId: afterMessageId, unacknowledged: false),
  sessionStatus: sessionStatus,
  hasPendingPrompts: hasPendingPrompts,
  editPhase: editPhase,
);

InterruptedTurnView _shown({
  required String afterMessageId,
  required String lineAfterMessageId,
  Set<String> supersededStoppedIds = const {},
  required InterruptedTurnContinueRefusal? continueRefusal,
}) => InterruptedTurnView.shown(
  afterMessageId: afterMessageId,
  lineAfterMessageId: lineAfterMessageId,
  supersededStoppedIds: supersededStoppedIds,
  continueRefusal: continueRefusal,
);

void main() {
  group("TurnEndCalculator", () {
    test("shows nothing without an interruption", () {
      expect(
        _view(
          messages: [
            _prompt(id: "u1"),
            _reply(id: "a1"),
          ],
          afterMessageId: null,
        ),
        const InterruptedTurnView.absent(),
      );
    });

    test("shows nothing while the interrupted message is not loaded", () {
      expect(
        _view(
          messages: [
            _prompt(id: "u2"),
            _reply(id: "a2"),
          ],
          afterMessageId: "a1",
        ),
        const InterruptedTurnView.absent(),
      );
    });

    test("ends the cut-off turn after its last message and offers Continue", () {
      expect(
        _view(
          messages: [
            _prompt(id: "u1"),
            _reply(id: "a1"),
            _reply(id: "a2"),
          ],
          afterMessageId: "a1",
        ),
        _shown(afterMessageId: "a1", lineAfterMessageId: "a2", continueRefusal: null),
      );
    });

    test("a turn cut off before any reply ends under its prompt, and Continue's prompt opens a new turn", () {
      expect(
        _view(
          messages: [_prompt(id: "u1")],
          afterMessageId: "u1",
        ),
        _shown(afterMessageId: "u1", lineAfterMessageId: "u1", continueRefusal: null),
      );

      // Continue's prompt follows with no reply between, yet the line stays
      // under the first prompt and the new turn takes Continue away.
      expect(
        _view(
          messages: [
            _prompt(id: "u1"),
            _prompt(id: "u2"),
          ],
          afterMessageId: "u1",
        ),
        _shown(
          afterMessageId: "u1",
          lineAfterMessageId: "u1",
          continueRefusal: InterruptedTurnContinueRefusal.laterTurn,
        ),
      );
    });

    test("a Stopped row the bridge stop left in the cut-off turn draws no line of its own", () {
      // Claude Code and Codex record the stop after the interrupted message,
      // so the row is the turn's last and the Interrupted line follows it.
      expect(
        _view(
          messages: [
            _prompt(id: "u1"),
            _reply(id: "a1"),
            _stopped(id: "e1"),
          ],
          afterMessageId: "a1",
        ),
        _shown(
          afterMessageId: "a1",
          lineAfterMessageId: "e1",
          supersededStoppedIds: {"e1"},
          continueRefusal: null,
        ),
      );
    });

    test("a Stopped row in another turn keeps its own line", () {
      expect(
        _view(
          messages: [
            _prompt(id: "u1"),
            _stopped(id: "e1"),
            _prompt(id: "u2"),
            _reply(id: "a2"),
          ],
          afterMessageId: "a2",
        ),
        _shown(afterMessageId: "a2", lineAfterMessageId: "a2", continueRefusal: null),
      );
    });

    test("offers no Continue while the session works or a prompt waits", () {
      final messages = [_prompt(id: "u1"), _reply(id: "a1")];
      expect(
        _view(messages: messages, afterMessageId: "a1", sessionStatus: const SessionStatus.busy(since: null)),
        _shown(
          afterMessageId: "a1",
          lineAfterMessageId: "a1",
          continueRefusal: InterruptedTurnContinueRefusal.sessionWorking,
        ),
      );
      expect(
        _view(
          messages: messages,
          afterMessageId: "a1",
          sessionStatus: const SessionStatus.retry(attempt: 1, message: "Overloaded", next: 0, since: null),
        ),
        _shown(
          afterMessageId: "a1",
          lineAfterMessageId: "a1",
          continueRefusal: InterruptedTurnContinueRefusal.sessionWorking,
        ),
      );
      expect(
        _view(messages: messages, afterMessageId: "a1", hasPendingPrompts: true),
        _shown(
          afterMessageId: "a1",
          lineAfterMessageId: "a1",
          continueRefusal: InterruptedTurnContinueRefusal.promptPending,
        ),
      );
    });

    test("an open or sending edit locks Continue, and a working session still wins", () {
      final messages = [_prompt(id: "u1"), _reply(id: "a1")];
      InterruptedTurnContinueRefusal? refusal({
        required SessionEditPhase editPhase,
        SessionStatus sessionStatus = const SessionStatus.idle(),
      }) => switch (_view(
        messages: messages,
        afterMessageId: "a1",
        sessionStatus: sessionStatus,
        hasPendingPrompts: true,
        editPhase: editPhase,
      )) {
        InterruptedTurnShown(:final continueRefusal) => continueRefusal,
        InterruptedTurnAbsent() => fail("the line should show"),
      };

      expect(refusal(editPhase: SessionEditPhase.restoring), InterruptedTurnContinueRefusal.editOpen);
      expect(refusal(editPhase: SessionEditPhase.composing), InterruptedTurnContinueRefusal.editOpen);
      expect(refusal(editPhase: SessionEditPhase.stopping), InterruptedTurnContinueRefusal.editSending);
      expect(refusal(editPhase: SessionEditPhase.sending), InterruptedTurnContinueRefusal.editSending);
      expect(
        refusal(editPhase: SessionEditPhase.composing, sessionStatus: const SessionStatus.busy(since: null)),
        InterruptedTurnContinueRefusal.sessionWorking,
      );
    });
  });
}
