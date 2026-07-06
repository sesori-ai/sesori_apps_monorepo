import "dart:async";
import "dart:convert";

import "package:sesori_bridge/src/control/bridge_control_message_dispatcher.dart";
import "package:sesori_bridge/src/foundation/control_channel_client.dart";
import "package:sesori_bridge/src/services/control_channel_token_service.dart";
import "package:sesori_bridge/src/services/control_prompt_service.dart";
import "package:sesori_bridge/src/services/control_unregister_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("BridgeControlMessageDispatcher", () {
    late _FakeControlChannelClient client;
    late _RecordingTokenService tokenService;
    late _RecordingPromptService promptService;
    late _RecordingUnregisterService unregisterService;
    late BridgeControlMessageDispatcher dispatcher;

    setUp(() {
      client = _FakeControlChannelClient();
      tokenService = _RecordingTokenService();
      promptService = _RecordingPromptService();
      unregisterService = _RecordingUnregisterService();
      dispatcher = BridgeControlMessageDispatcher(
        client: client,
        tokenService: tokenService,
        promptService: promptService,
        unregisterService: unregisterService,
      );
      addTearDown(dispatcher.dispose);
    });

    test("routes token_response to the token service delegate", () async {
      dispatcher.start();
      client.emit(_encode(const ControlMessage.tokenResponse(id: "t-1", accessToken: "tok")));
      client.emit(_encode(const ControlMessage.tokenResponse(id: "t-2", accessToken: null)));
      await pumpEventQueue();

      expect(tokenService.responses, equals([("t-1", "tok"), ("t-2", null)]));
      expect(tokenService.updates, isEmpty);
      expect(promptService.responses, isEmpty);
    });

    test("routes token_update to the token service delegate", () async {
      dispatcher.start();
      client.emit(_encode(const ControlMessage.tokenUpdate(accessToken: "pushed")));
      await pumpEventQueue();

      expect(tokenService.updates, equals(["pushed"]));
      expect(tokenService.responses, isEmpty);
    });

    test("routes prompt_response to the prompt service delegate", () async {
      dispatcher.start();
      client.emit(_encode(const ControlMessage.promptResponse(id: "p-1", accepted: true)));
      client.emit(_encode(const ControlMessage.promptResponse(id: "p-2", accepted: false)));
      await pumpEventQueue();

      expect(promptService.responses, equals([("p-1", true), ("p-2", false)]));
      expect(tokenService.responses, isEmpty);
    });

    test("routes unregister_and_exit to the unregister service delegate", () async {
      dispatcher.start();
      client.emit(_encode(const ControlMessage.unregisterAndExit()));
      await pumpEventQueue();

      expect(unregisterService.calls, equals(1));
      expect(tokenService.responses, isEmpty);
      expect(promptService.responses, isEmpty);
    });

    test("an undecodable frame is skipped and later frames are still routed", () async {
      dispatcher.start();
      client.emit("not valid json");
      client.emit(_encode(const ControlMessage.tokenUpdate(accessToken: "after-garbage")));
      await pumpEventQueue();

      expect(tokenService.updates, equals(["after-garbage"]));
    });

    test("variants with no inbound meaning are ignored — restart is never an inbound command", () async {
      dispatcher.start();
      client.emit(_encode(const ControlMessage.restart()));
      client.emit(_encode(const ControlMessage.registered(bridgeId: "b-1")));
      client.emit(_encode(const ControlMessage.tokenRequest(id: "t-1")));
      client.emit(
        _encode(
          const ControlMessage.status(
            relay: ControlRelayConnectionState.connected,
            plugin: ControlPluginHealthState.healthy,
          ),
        ),
      );
      await pumpEventQueue();

      expect(tokenService.responses, isEmpty);
      expect(tokenService.updates, isEmpty);
      expect(promptService.responses, isEmpty);
      expect(unregisterService.calls, isZero);
    });

    test("the dispatcher is the only inbound subscriber — services never self-subscribe", () async {
      // Constructing the real services must not subscribe to the client.
      final realTokenService = ControlChannelTokenService(client: client);
      addTearDown(realTokenService.dispose);
      final realPromptService = ControlPromptService(client: client);
      addTearDown(realPromptService.dispose);
      expect(client.listenCount, equals(0));

      final wired = BridgeControlMessageDispatcher(
        client: client,
        tokenService: realTokenService,
        promptService: realPromptService,
        unregisterService: _RecordingUnregisterService(),
      );
      addTearDown(wired.dispose);
      wired.start();
      expect(client.listenCount, equals(1));

      // start() is idempotent: no second subscription.
      wired.start();
      expect(client.listenCount, equals(1));
    });

    test("frames after dispose are not routed", () async {
      dispatcher.start();
      await dispatcher.dispose();
      client.emit(_encode(const ControlMessage.tokenUpdate(accessToken: "late")));
      await pumpEventQueue();

      expect(tokenService.updates, isEmpty);
    });
  });
}

String _encode(ControlMessage message) => jsonEncode(message.toJson());

class _FakeControlChannelClient implements ControlChannelClient {
  final StreamController<String> _inbound = StreamController<String>.broadcast();
  int listenCount = 0;

  void emit(String frame) => _inbound.add(frame);

  @override
  Stream<String> get inbound {
    // Counts every listen while keeping subscription synchronous (an async*
    // wrapper would subscribe in a microtask and miss synchronously emitted
    // frames).
    return Stream<String>.multi((controller) {
      listenCount++;
      final subscription = _inbound.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  void send(String frame) {}

  @override
  Stream<ControlChannelConnectionState> get connectionState => const Stream<ControlChannelConnectionState>.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {
    await _inbound.close();
  }
}

class _RecordingTokenService implements ControlChannelTokenService {
  final List<(String, String?)> responses = <(String, String?)>[];
  final List<String> updates = <String>[];

  @override
  void handleTokenResponse({required String id, required String? accessToken}) => responses.add((id, accessToken));

  @override
  void handleTokenUpdate({required String accessToken}) => updates.add(accessToken);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingPromptService implements ControlPromptService {
  final List<(String, bool)> responses = <(String, bool)>[];

  @override
  void handlePromptResponse({required String id, required bool accepted}) => responses.add((id, accepted));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingUnregisterService implements ControlUnregisterService {
  int calls = 0;

  @override
  Future<void> handleUnregisterAndExit() async => calls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
