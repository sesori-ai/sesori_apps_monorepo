import "dart:async";
import "dart:convert";
import "dart:io";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockAuthTokenProvider extends Mock implements AuthTokenProvider {}

void main() {
  late ControlChannelServer server;
  late _MockAuthTokenProvider tokenProvider;
  late BridgeStatusTracker statusTracker;
  late BridgePromptTracker promptTracker;
  late ControlMessageDispatcher dispatcher;

  setUp(() async {
    server = ControlChannelServer();
    await server.start();
    tokenProvider = _MockAuthTokenProvider();
    statusTracker = BridgeStatusTracker();
    promptTracker = BridgePromptTracker();
    dispatcher = ControlMessageDispatcher(
      server: server,
      tokenProvider: tokenProvider,
      statusTracker: statusTracker,
      promptTracker: promptTracker,
    );
    dispatcher.start();
    addTearDown(() async {
      await dispatcher.dispose();
      await server.dispose();
      statusTracker.dispose();
      promptTracker.dispose();
    });
  });

  Future<WebSocket> connectHelper() async {
    final WebSocket helper = await WebSocket.connect(
      server.url.toString(),
      headers: <String, dynamic>{"Authorization": "Bearer ${server.secret}"},
    );
    addTearDown(helper.close);
    await statusTracker.statusStream.firstWhere((status) => status.helperOnline);
    return helper;
  }

  void sendFromHelper(WebSocket helper, ControlMessage message) {
    helper.add(jsonEncode(message.toJson()));
  }

  test("answers token_request with an id-correlated token_response", () async {
    when(() => tokenProvider.getFreshAccessToken(forceRefresh: false)).thenAnswer((_) async => "jwt-1");
    final WebSocket helper = await connectHelper();
    final Future<Object?> reply = helper.first;

    sendFromHelper(helper, const ControlMessage.tokenRequest(id: "42"));

    final Map<String, dynamic> decoded = jsonDecodeMap(await reply as String? ?? "");
    final ControlMessage response = ControlMessage.fromJson(decoded);
    expect(response, const ControlMessage.tokenResponse(id: "42", accessToken: "jwt-1"));
  });

  test("forwards forceRefresh to the token seam", () async {
    when(() => tokenProvider.getFreshAccessToken(forceRefresh: true)).thenAnswer((_) async => "jwt-2");
    final WebSocket helper = await connectHelper();
    final Future<Object?> reply = helper.first;

    sendFromHelper(helper, const ControlMessage.tokenRequest(id: "43", forceRefresh: true));

    await reply;
    verify(() => tokenProvider.getFreshAccessToken(forceRefresh: true)).called(1);
  });

  test("a signed-out session answers with a null accessToken", () async {
    when(() => tokenProvider.getFreshAccessToken(forceRefresh: false)).thenAnswer((_) async => null);
    final WebSocket helper = await connectHelper();
    final Future<Object?> reply = helper.first;

    sendFromHelper(helper, const ControlMessage.tokenRequest(id: "44"));

    final ControlMessage response = ControlMessage.fromJson(jsonDecodeMap(await reply as String? ?? ""));
    expect(response, const ControlMessage.tokenResponse(id: "44", accessToken: null));
  });

  test("a throwing token seam degrades to a signed-out response", () async {
    when(() => tokenProvider.getFreshAccessToken(forceRefresh: false)).thenThrow(StateError("refresh broke"));
    final WebSocket helper = await connectHelper();
    final Future<Object?> reply = helper.first;

    sendFromHelper(helper, const ControlMessage.tokenRequest(id: "45"));

    final ControlMessage response = ControlMessage.fromJson(jsonDecodeMap(await reply as String? ?? ""));
    expect(response, const ControlMessage.tokenResponse(id: "45", accessToken: null));
  });

  test("status frames land in the status tracker", () async {
    final WebSocket helper = await connectHelper();

    sendFromHelper(
      helper,
      const ControlMessage.status(
        relay: ControlRelayConnectionState.connected,
        plugin: ControlPluginHealthState.healthy,
        activeSessionCount: 2,
      ),
    );
    await statusTracker.statusStream.firstWhere(
      (status) => status.relay == ControlRelayConnectionState.connected,
    );

    expect(statusTracker.status.plugin, ControlPluginHealthState.healthy);
    expect(statusTracker.status.activeSessionCount, 2);
  });

  test("registered frames record the bridge id", () async {
    final WebSocket helper = await connectHelper();

    sendFromHelper(helper, const ControlMessage.registered(bridgeId: "bridge-9"));
    await statusTracker.statusStream.firstWhere((status) => status.bridgeId != null);

    expect(statusTracker.status.bridgeId, "bridge-9");
  });

  test("prompt requests land in the prompt tracker", () async {
    final WebSocket helper = await connectHelper();
    const ControlMessage prompt = ControlMessage.promptRequest(
      id: "p1",
      kind: ControlPromptKind.replaceBridge,
      message: "Replace?",
    );

    sendFromHelper(helper, prompt);
    await promptTracker.promptsStream.firstWhere((prompts) => prompts.isNotEmpty);

    expect(promptTracker.prompts.single.id, "p1");
  });

  test("an undecodable frame is skipped and the pipeline keeps working", () async {
    final WebSocket helper = await connectHelper();

    helper.add("not json at all");
    sendFromHelper(helper, const ControlMessage.registered(bridgeId: "after-garbage"));
    await statusTracker.statusStream.firstWhere((status) => status.bridgeId != null);

    expect(statusTracker.status.bridgeId, "after-garbage");
  });

  test("GUI-direction and advisory variants are ignored without crashing", () async {
    final WebSocket helper = await connectHelper();

    sendFromHelper(helper, const ControlMessage.restart());
    sendFromHelper(helper, const ControlMessage.tokenUpdate(accessToken: "x"));
    sendFromHelper(helper, const ControlMessage.unregisterAndExit());
    sendFromHelper(
      helper,
      const ControlMessage.provisionProgress(progress: ControlProvisionProgress.resolving()),
    );
    sendFromHelper(helper, const ControlMessage.registered(bridgeId: "still-alive"));
    await statusTracker.statusStream.firstWhere((status) => status.bridgeId != null);

    expect(statusTracker.status.bridgeId, "still-alive");
  });

  test("helper connect/disconnect drive the trackers and clear prompts", () async {
    final WebSocket helper = await connectHelper();
    sendFromHelper(
      helper,
      const ControlMessage.promptRequest(id: "p2", kind: ControlPromptKind.loginNeeded, message: null),
    );
    await promptTracker.promptsStream.firstWhere((prompts) => prompts.isNotEmpty);
    expect(statusTracker.status.helperOnline, isTrue);

    await helper.close();
    await statusTracker.statusStream.firstWhere((status) => !status.helperOnline);

    expect(promptTracker.prompts, isEmpty);
  });
}
