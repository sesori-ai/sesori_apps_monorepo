import "dart:async";

import "package:sesori_bridge/src/foundation/control_channel_client.dart";
import "package:sesori_bridge/src/server/foundation/terminal_prompt_decision.dart";
import "package:sesori_bridge/src/services/control_prompt_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ControlPromptService", () {
    test("askReplaceExistingBridge sends a replace_bridge prompt and maps accepted to replace", () async {
      final client = _FakeControlChannelClient();
      final service = ControlPromptService(client: client);
      addTearDown(service.dispose);

      final future = service.askReplaceExistingBridge(bridgeCount: 1);
      await pumpEventQueue();

      final request = _decode(client.sentFrames.single) as ControlPromptRequest;
      expect(request.kind, equals(ControlPromptKind.replaceBridge));
      expect(request.message, contains("already running"));

      service.handlePromptResponse(id: request.id, accepted: true);
      expect(await future, equals(TerminalPromptDecision.replace));
    });

    test("askReplaceStartingBridge maps a rejected answer to decline", () async {
      final client = _FakeControlChannelClient();
      final service = ControlPromptService(client: client);
      addTearDown(service.dispose);

      final future = service.askReplaceStartingBridge(holderPid: 4242);
      await pumpEventQueue();

      final request = _decode(client.sentFrames.single) as ControlPromptRequest;
      expect(request.kind, equals(ControlPromptKind.replaceBridge));
      expect(request.message, contains("4242"));

      service.handlePromptResponse(id: request.id, accepted: false);
      expect(await future, equals(TerminalPromptDecision.decline));
    });

    test("correlates by id — a mismatched answer is ignored", () async {
      final client = _FakeControlChannelClient();
      final service = ControlPromptService(client: client);
      addTearDown(service.dispose);

      final future = service.askReplaceExistingBridge(bridgeCount: 1);
      await pumpEventQueue();
      final request = _decode(client.sentFrames.single) as ControlPromptRequest;

      service.handlePromptResponse(id: "someone-else", accepted: true);
      service.handlePromptResponse(id: request.id, accepted: false);

      expect(await future, equals(TerminalPromptDecision.decline));
    });

    test("no answer within the timeout degrades to nonInteractive", () async {
      final client = _FakeControlChannelClient();
      final service = ControlPromptService(
        client: client,
        responseTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(service.dispose);

      expect(
        await service.askReplaceExistingBridge(bridgeCount: 1),
        equals(TerminalPromptDecision.nonInteractive),
      );
    });

    test("a disconnected channel degrades to nonInteractive", () async {
      final client = _FakeControlChannelClient()..throwOnSend = true;
      final service = ControlPromptService(client: client);
      addTearDown(service.dispose);

      expect(
        await service.askReplaceExistingBridge(bridgeCount: 1),
        equals(TerminalPromptDecision.nonInteractive),
      );
    });

    test("dispose resolves an in-flight ask as nonInteractive", () async {
      final client = _FakeControlChannelClient();
      final service = ControlPromptService(client: client);

      final future = service.askReplaceExistingBridge(bridgeCount: 1);
      await pumpEventQueue();

      await service.dispose();
      expect(await future, equals(TerminalPromptDecision.nonInteractive));
    });

    test("an ask after dispose is nonInteractive without sending", () async {
      final client = _FakeControlChannelClient();
      final service = ControlPromptService(client: client);
      await service.dispose();

      expect(
        await service.askReplaceExistingBridge(bridgeCount: 1),
        equals(TerminalPromptDecision.nonInteractive),
      );
      expect(client.sentFrames, isEmpty);
    });

    test("announceLoginNeeded sends a login_needed prompt without awaiting an answer", () async {
      final client = _FakeControlChannelClient();
      final service = ControlPromptService(client: client);
      addTearDown(service.dispose);

      service.announceLoginNeeded();

      final request = _decode(client.sentFrames.single) as ControlPromptRequest;
      expect(request.kind, equals(ControlPromptKind.loginNeeded));
    });

    test("announceLoginNeeded is best-effort — a disconnected channel does not throw", () {
      final client = _FakeControlChannelClient()..throwOnSend = true;
      final service = ControlPromptService(client: client);
      addTearDown(service.dispose);

      expect(service.announceLoginNeeded, returnsNormally);
      expect(client.sentFrames, isEmpty);
    });
  });
}

ControlMessage _decode(String frame) => ControlMessage.fromJson(jsonDecodeMap(frame));

class _FakeControlChannelClient implements ControlChannelClient {
  final List<String> sentFrames = <String>[];

  /// Mimics [ControlChannelClient.send] throwing when the channel is down.
  bool throwOnSend = false;

  @override
  Stream<String> get inbound => const Stream<String>.empty();

  @override
  void send(String frame) {
    if (throwOnSend) {
      throw const ControlChannelNotConnectedException("Control channel is not connected");
    }
    sentFrames.add(frame);
  }

  @override
  Stream<ControlChannelConnectionState> get connectionState => const Stream<ControlChannelConnectionState>.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {}
}
