import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ControlCommandService", () {
    late _FakeControlChannelServer server;
    late BridgePromptTracker promptTracker;
    late ControlCommandService service;

    setUp(() {
      server = _FakeControlChannelServer();
      promptTracker = BridgePromptTracker();
      service = ControlCommandService(
        server: server,
        promptTracker: promptTracker,
      );
    });

    tearDown(() => promptTracker.dispose());

    test("sends a typed prompt response and clears the answered prompt", () {
      promptTracker.addPrompt(prompt: _prompt);

      service.answerPrompt(id: _prompt.id, accepted: true);

      expect(server.sentFrames, hasLength(1));
      expect(
        ControlMessage.fromJson(jsonDecodeMap(server.sentFrames.single)),
        const ControlMessage.promptResponse(id: "replace-1", accepted: true),
      );
      expect(promptTracker.prompts, isEmpty);
    });

    test("retains the prompt when the connected helper cannot accept the frame", () {
      promptTracker.addPrompt(prompt: _prompt);
      const ControlHelperNotConnectedException sendError = ControlHelperNotConnectedException();
      server.sendError = sendError;

      expect(
        () => service.answerPrompt(id: _prompt.id, accepted: false),
        throwsA(same(sendError)),
      );

      expect(promptTracker.prompts, <ControlPromptRequest>[_prompt]);
    });

    test("rejects a stale prompt id before sending to a newer helper", () {
      expect(
        () => service.answerPrompt(id: "stale", accepted: true),
        throwsA(
          isA<ControlPromptNotPendingException>().having(
            (error) => error.id,
            "id",
            "stale",
          ),
        ),
      );

      expect(server.sentFrames, isEmpty);
    });
  });
}

const ControlPromptRequest _prompt = ControlPromptRequest(
  id: "replace-1",
  kind: ControlPromptKind.replaceBridge,
  message: "Replace the running bridge?",
);

class _FakeControlChannelServer() implements ControlChannelServer {
  final List<String> sentFrames = <String>[];
  Object? sendError;

  @override
  void send(String text) {
    final Object? failure = sendError;
    if (failure != null) {
      throw failure;
    }
    sentFrames.add(text);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
