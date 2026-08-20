import "package:sesori_bridge/src/bridge/services/prompt_echo_correlator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

Message _userMessage({String id = "msg-1", String sessionId = "s-1", String? promptId}) =>
    Message.user(id: id, sessionID: sessionId, agent: null, time: null, promptId: promptId);

void main() {
  group("PromptEchoCorrelator", () {
    test("stamps an unattributed echo with the prompt the bridge dispatched", () {
      final correlator = PromptEchoCorrelator();
      correlator.recordDispatched(sessionId: "s-1", promptId: "prm_1");

      final stamped = correlator.stamp(sessionId: "s-1", message: _userMessage());

      expect((stamped as MessageUser).promptId, "prm_1");
    });

    test("claims each dispatch once, in dispatch order", () {
      final correlator = PromptEchoCorrelator();
      correlator.recordDispatched(sessionId: "s-1", promptId: "prm_1");
      correlator.recordDispatched(sessionId: "s-1", promptId: "prm_2");

      final first = correlator.stamp(
        sessionId: "s-1",
        message: _userMessage(id: "msg-1"),
      ) as MessageUser;
      final second = correlator.stamp(
        sessionId: "s-1",
        message: _userMessage(id: "msg-2"),
      ) as MessageUser;
      final third = correlator.stamp(
        sessionId: "s-1",
        message: _userMessage(id: "msg-3"),
      ) as MessageUser;

      expect(first.promptId, "prm_1");
      expect(second.promptId, "prm_2");
      expect(third.promptId, isNull, reason: "no dispatch is left to claim this one");
    });

    test("leaves a harness's own correlation intact", () {
      final correlator = PromptEchoCorrelator();
      correlator.recordDispatched(sessionId: "s-1", promptId: "prm_bridge");

      final stamped = correlator.stamp(
        sessionId: "s-1",
        message: _userMessage(promptId: "prm_harness"),
      ) as MessageUser;

      expect(stamped.promptId, "prm_harness");
      // The unclaimed dispatch stays available for the echo it belongs to.
      expect(
        (correlator.stamp(
          sessionId: "s-1",
          message: _userMessage(id: "msg-2"),
        ) as MessageUser).promptId,
        "prm_bridge",
      );
    });

    test("keeps sessions independent and never stamps assistant messages", () {
      final correlator = PromptEchoCorrelator();
      correlator.recordDispatched(sessionId: "s-1", promptId: "prm_1");

      final otherSession = correlator.stamp(
        sessionId: "s-2",
        message: _userMessage(sessionId: "s-2"),
      ) as MessageUser;
      expect(otherSession.promptId, isNull);

      const assistant = Message.assistant(
        id: "a-1",
        sessionID: "s-1",
        agent: null,
        modelID: null,
        providerID: null,
        time: null,
      );
      expect(correlator.stamp(sessionId: "s-1", message: assistant), same(assistant));
    });

    test("repeated envelopes of one message resolve to the same prompt", () {
      final correlator = PromptEchoCorrelator();
      correlator.recordDispatched(sessionId: "s-1", promptId: "prm_1");
      correlator.recordDispatched(sessionId: "s-1", promptId: "prm_2");

      // A backend that publishes started/completed pairs updates one message
      // twice; the second update must not consume the next send's id.
      final first = correlator.stamp(
        sessionId: "s-1",
        message: _userMessage(id: "msg-1"),
      ) as MessageUser;
      final repeat = correlator.stamp(
        sessionId: "s-1",
        message: _userMessage(id: "msg-1"),
      ) as MessageUser;
      final next = correlator.stamp(
        sessionId: "s-1",
        message: _userMessage(id: "msg-2"),
      ) as MessageUser;

      expect(first.promptId, "prm_1");
      expect(repeat.promptId, "prm_1");
      expect(next.promptId, "prm_2", reason: "the second send keeps its own id");
    });

    test("a refused dispatch is never claimed by a later echo", () {
      final correlator = PromptEchoCorrelator();
      correlator.recordDispatched(sessionId: "s-1", promptId: "prm_refused");
      correlator.forgetPrompt(sessionId: "s-1", promptId: "prm_refused");
      correlator.recordDispatched(sessionId: "s-1", promptId: "prm_accepted");

      final stamped = correlator.stamp(sessionId: "s-1", message: _userMessage()) as MessageUser;

      expect(stamped.promptId, "prm_accepted");
    });

    test("an echo carrying the dispatched id retires that dispatch", () {
      final correlator = PromptEchoCorrelator();
      correlator.recordDispatched(sessionId: "s-1", promptId: "prm_1");
      correlator.recordDispatched(sessionId: "s-1", promptId: "prm_2");

      // A backend that stamps the bridge's own id has claimed that dispatch;
      // leaving it pending would let the next echo take it.
      correlator.stamp(
        sessionId: "s-1",
        message: _userMessage(id: "msg-1", promptId: "prm_1"),
      );
      final next = correlator.stamp(
        sessionId: "s-1",
        message: _userMessage(id: "msg-2"),
      ) as MessageUser;

      expect(next.promptId, "prm_2");
    });

    test("forgetting a session drops its unclaimed dispatches", () {
      final correlator = PromptEchoCorrelator();
      correlator.recordDispatched(sessionId: "s-1", promptId: "prm_1");
      correlator.forgetSession(sessionId: "s-1");

      expect((correlator.stamp(sessionId: "s-1", message: _userMessage()) as MessageUser).promptId, isNull);
    });

    test("bounds unclaimed dispatches so a silent harness cannot mis-stamp later", () {
      final correlator = PromptEchoCorrelator();
      for (var i = 0; i < 68; i++) {
        correlator.recordDispatched(sessionId: "s-1", promptId: "prm_$i");
      }

      // The oldest were dropped; the newest dispatch is still claimable.
      final stamped = correlator.stamp(sessionId: "s-1", message: _userMessage()) as MessageUser;
      expect(stamped.promptId, "prm_4");
    });
  });
}
