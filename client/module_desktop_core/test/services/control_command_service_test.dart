import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ControlCommandService", () {
    late _FakeControlChannelApi api;
    late BridgePromptTracker promptTracker;
    late ControlCommandService service;

    setUp(() {
      api = _FakeControlChannelApi();
      promptTracker = BridgePromptTracker();
      service = ControlCommandService(
        repository: ControlCommandRepository(api: api),
        promptTracker: promptTracker,
      );
    });

    tearDown(() => promptTracker.dispose());

    test("sends a typed prompt response and clears the answered prompt", () {
      promptTracker.addPrompt(prompt: _prompt);

      service.answerPrompt(prompt: _prompt, accepted: true);

      expect(
        api.sentMessages,
        <ControlMessage>[const ControlMessage.promptResponse(id: "replace-1", accepted: true)],
      );
      expect(promptTracker.prompts, isEmpty);
    });

    test("sends unregister_and_exit without requiring a pending prompt", () {
      service.unregisterAndExit();

      expect(
        api.sentMessages,
        <ControlMessage>[const ControlMessage.unregisterAndExit()],
      );
    });

    test("retains the prompt when the connected helper cannot accept the frame", () {
      promptTracker.addPrompt(prompt: _prompt);
      const ControlHelperNotConnectedException sendError = ControlHelperNotConnectedException();
      api.sendError = sendError;

      expect(
        () => service.answerPrompt(prompt: _prompt, accepted: false),
        throwsA(same(sendError)),
      );

      expect(promptTracker.prompts, <ControlPromptRequest>[_prompt]);
    });

    test("rejects a stale prompt instance when a replacement reuses its id", () {
      promptTracker.addPrompt(prompt: _prompt);
      promptTracker.clear();
      final ControlPromptRequest replacement = ControlPromptRequest(
        id: _prompt.id,
        kind: _prompt.kind,
        message: _prompt.message,
      );
      promptTracker.addPrompt(prompt: replacement);

      expect(
        () => service.answerPrompt(prompt: _prompt, accepted: true),
        throwsA(
          isA<ControlPromptNotPendingException>().having(
            (error) => error.id,
            "id",
            _prompt.id,
          ),
        ),
      );

      expect(api.sentMessages, isEmpty);
      expect(promptTracker.prompts, <ControlPromptRequest>[replacement]);
    });
  });
}

const ControlPromptRequest _prompt = ControlPromptRequest(
  id: "replace-1",
  kind: ControlPromptKind.replaceBridge,
  message: "Replace the running bridge?",
);

class _FakeControlChannelApi() implements ControlChannelApi {
  final List<ControlMessage> sentMessages = <ControlMessage>[];
  Object? sendError;

  @override
  void send({required ControlMessage message}) {
    final Object? failure = sendError;
    if (failure != null) {
      throw failure;
    }
    sentMessages.add(message);
  }
}
