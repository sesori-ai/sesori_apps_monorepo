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

    test("forgetting a session drops its unclaimed dispatches", () {
      final correlator = PromptEchoCorrelator();
      correlator.recordDispatched(sessionId: "s-1", promptId: "prm_1");
      correlator.forgetSession(sessionId: "s-1");

      expect((correlator.stamp(sessionId: "s-1", message: _userMessage()) as MessageUser).promptId, isNull);
    });

    test("bounds unclaimed dispatches so a silent harness cannot mis-stamp later", () {
      final correlator = PromptEchoCorrelator();
      for (var i = 0; i < 12; i++) {
        correlator.recordDispatched(sessionId: "s-1", promptId: "prm_$i");
      }

      // The oldest were dropped; the newest dispatch is still claimable.
      final stamped = correlator.stamp(sessionId: "s-1", message: _userMessage()) as MessageUser;
      expect(stamped.promptId, "prm_4");
    });
  });
}
