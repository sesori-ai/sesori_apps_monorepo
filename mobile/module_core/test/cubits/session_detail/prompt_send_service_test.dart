import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/session_detail/prompt_send_service.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  group("PromptSendService", () {
    late MockSessionService mockSessionService;

    setUp(() {
      mockSessionService = MockSessionService();
    });

    test("drain sends queued messages with fresh params each iteration", () async {
      const sessionId = "session-1";
      var currentAgent = "agent-old";
      var currentProviderID = "provider-old";
      var currentModelID = "model-old";
      var isConnected = true;

      final sentParams = <({String? agent, String? providerID, String? modelID})>[];
      final firstSendStarted = Completer<void>();
      final allowFirstSendToComplete = Completer<void>();

      when(
        () => mockSessionService.sendMessage(
          sessionId,
          any(),
          agent: any(named: "agent"),
          providerID: any(named: "providerID"),
          modelID: any(named: "modelID"),
        ),
      ).thenAnswer((invocation) async {
        sentParams.add(
          (
            agent: invocation.namedArguments[#agent] as String?,
            providerID: invocation.namedArguments[#providerID] as String?,
            modelID: invocation.namedArguments[#modelID] as String?,
          ),
        );

        if ((invocation.positionalArguments[1] as String) == "first") {
          firstSendStarted.complete();
          await allowFirstSendToComplete.future;
        }

        return ApiResponse<void>.success(null);
      });

      final service = PromptSendService(
        service: mockSessionService,
        sessionId: sessionId,
        onQueueChanged: () {},
        stateProvider: () => (
          agent: currentAgent,
          providerID: currentProviderID,
          modelID: currentModelID,
          isConnected: isConnected,
          isLoaded: true,
        ),
      );

      await service.sendMessage(
        text: "first",
        agent: "agent-old",
        providerID: "provider-old",
        modelID: "model-old",
        isConnected: false,
      );
      await service.sendMessage(
        text: "second",
        agent: "agent-old",
        providerID: "provider-old",
        modelID: "model-old",
        isConnected: false,
      );

      service.drain();

      await firstSendStarted.future;

      currentAgent = "agent-new";
      currentProviderID = "provider-new";
      currentModelID = "model-new";
      isConnected = true;

      allowFirstSendToComplete.complete();

      await _waitFor(condition: () => sentParams.length == 2);

      expect(sentParams[0], (agent: "agent-old", providerID: "provider-old", modelID: "model-old"));
      expect(sentParams[1], (agent: "agent-new", providerID: "provider-new", modelID: "model-new"));
    });

    test("drain stops when state becomes not loaded mid-drain", () async {
      const sessionId = "session-1";
      var isLoaded = true;

      final firstSendStarted = Completer<void>();
      final allowFirstSendToComplete = Completer<void>();

      when(
        () => mockSessionService.sendMessage(
          sessionId,
          any(),
          agent: any(named: "agent"),
          providerID: any(named: "providerID"),
          modelID: any(named: "modelID"),
        ),
      ).thenAnswer((invocation) async {
        if ((invocation.positionalArguments[1] as String) == "first") {
          firstSendStarted.complete();
          await allowFirstSendToComplete.future;
        }

        return ApiResponse<void>.success(null);
      });

      final service = PromptSendService(
        service: mockSessionService,
        sessionId: sessionId,
        onQueueChanged: () {},
        stateProvider: () => (
          agent: "agent",
          providerID: "provider",
          modelID: "model",
          isConnected: true,
          isLoaded: isLoaded,
        ),
      );

      await service.sendMessage(
        text: "first",
        agent: "agent",
        providerID: "provider",
        modelID: "model",
        isConnected: false,
      );
      await service.sendMessage(
        text: "second",
        agent: "agent",
        providerID: "provider",
        modelID: "model",
        isConnected: false,
      );

      service.drain();
      await firstSendStarted.future;

      isLoaded = false;
      allowFirstSendToComplete.complete();

      await Future<void>.delayed(const Duration(milliseconds: 20));

      verify(
        () => mockSessionService.sendMessage(
          sessionId,
          "first",
          agent: any(named: "agent"),
          providerID: any(named: "providerID"),
          modelID: any(named: "modelID"),
        ),
      ).called(1);
      verifyNever(
        () => mockSessionService.sendMessage(
          sessionId,
          "second",
          agent: any(named: "agent"),
          providerID: any(named: "providerID"),
          modelID: any(named: "modelID"),
        ),
      );
    });

    test("queued commands drain through sendCommand when connection returns", () async {
      const sessionId = "session-1";
      var isConnected = false;

      when(
        () => mockSessionService.sendCommand(
          sessionId: sessionId,
          command: any(named: "command"),
          arguments: any(named: "arguments"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));

      final service = PromptSendService(
        service: mockSessionService,
        sessionId: sessionId,
        onQueueChanged: () {},
        stateProvider: () => (
          agent: "agent",
          providerID: "provider",
          modelID: "model",
          isConnected: isConnected,
          isLoaded: true,
        ),
      );

      await service.sendCommand(
        command: "review",
        arguments: "lib/main.dart",
        isConnected: false,
      );

      expect(service.queuedMessages.single.displayText, "/review lib/main.dart");

      isConnected = true;
      service.drain();
      await _waitFor(condition: () => service.isEmpty);

      verify(
        () => mockSessionService.sendCommand(
          sessionId: sessionId,
          command: "review",
          arguments: "lib/main.dart",
        ),
      ).called(1);
    });
  });
}

Future<void> _waitFor({required bool Function() condition}) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail("Timed out waiting for condition");
}
