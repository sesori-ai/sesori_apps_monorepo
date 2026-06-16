import "dart:typed_data";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/platform/media_picker.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  test("session detail flows route through session api and repository", () async {
    final api = MockSessionApi();
    final repository = SessionRepository(api: api);

    when(() => api.getMessages(sessionId: "session-1")).thenAnswer(
      (_) async => ApiResponse.success(const MessageWithPartsResponse(messages: <MessageWithParts>[])),
    );
    when(() => api.getPendingQuestions(sessionId: "session-1")).thenAnswer(
      (_) async => ApiResponse.success(const PendingQuestionResponse(data: <PendingQuestion>[])),
    );
    when(api.getPendingPermissions).thenAnswer(
      (_) async => ApiResponse.success(const PendingPermissionResponse(data: <PendingPermission>[])),
    );
    when(() => api.getChildren(sessionId: "session-1")).thenAnswer(
      (_) async => ApiResponse.success(const SessionListResponse(items: <Session>[])),
    );
    when(api.getSessionStatuses).thenAnswer(
      (_) async => ApiResponse.success(const SessionStatusResponse(statuses: <String, SessionStatus>{})),
    );
    when(
      () => api.listAgents(projectId: any(named: "projectId")),
    ).thenAnswer((_) async => ApiResponse.success(const Agents(agents: <AgentInfo>[])));
    when(() => api.listProviders(projectId: any(named: "projectId"))).thenAnswer(
      (_) async => ApiResponse.success(const ProviderListResponse(connectedOnly: false, items: <ProviderInfo>[])),
    );
    when(() => api.listCommands(projectId: "project-1")).thenAnswer(
      (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
    );
    when(
      () => api.sendMessage(
        sessionId: "session-1",
        parts: any(named: "parts"),
        agent: "build",
        model: const PromptModel(providerID: "openai", modelID: "gpt-4.1"),
        variant: const SessionVariant(id: "xhigh"),
        command: "review",
      ),
    ).thenAnswer((_) async => ApiResponse.success(null));
    when(
      () => api.abortSession(sessionId: "session-1"),
    ).thenAnswer((_) async => ApiResponse.success(const SuccessEmptyResponse()));
    when(
      () => api.replyToQuestion(
        requestId: "question-1",
        sessionId: "session-1",
        answers: const [
          ReplyAnswer(values: <String>["Yes"]),
        ],
      ),
    ).thenAnswer((_) async => ApiResponse.success(null));
    when(() => api.rejectQuestion(requestId: "question-1")).thenAnswer((_) async => ApiResponse.success(null));
    await repository.getMessages(sessionId: "session-1");
    await repository.getPendingQuestions(sessionId: "session-1");
    await repository.getPendingPermissions();
    await repository.getChildren(sessionId: "session-1");
    await repository.getSessionStatuses();
    await repository.listAgents(projectId: "project-1");
    await repository.listProviders(projectId: "project-1");
    await repository.listCommands(projectId: "project-1");
    await repository.sendMessage(
      sessionId: "session-1",
      text: "hello",
      attachments: const [],
      agent: "build",
      model: const PromptModel(providerID: "openai", modelID: "gpt-4.1"),
      variant: const SessionVariant(id: "xhigh"),
      command: "review",
    );
    await repository.abortSession(sessionId: "session-1");
    await repository.replyToQuestion(
      requestId: "question-1",
      sessionId: "session-1",
      answers: const [
        ReplyAnswer(values: <String>["Yes"]),
      ],
    );
    await repository.rejectQuestion(requestId: "question-1");
    verify(() => api.getMessages(sessionId: "session-1")).called(1);
    verify(() => api.getPendingQuestions(sessionId: "session-1")).called(1);
    verify(api.getPendingPermissions).called(1);
    verify(() => api.getChildren(sessionId: "session-1")).called(1);
    verify(api.getSessionStatuses).called(1);
    verify(() => api.listAgents(projectId: "project-1")).called(1);
    verify(() => api.listProviders(projectId: "project-1")).called(1);
    verify(() => api.listCommands(projectId: "project-1")).called(1);
    verify(
      () => api.sendMessage(
        sessionId: "session-1",
        parts: any(named: "parts"),
        agent: "build",
        model: const PromptModel(providerID: "openai", modelID: "gpt-4.1"),
        variant: const SessionVariant(id: "xhigh"),
        command: "review",
      ),
    ).called(1);
    verify(() => api.abortSession(sessionId: "session-1")).called(1);
    verify(
      () => api.replyToQuestion(
        requestId: "question-1",
        sessionId: "session-1",
        answers: const [
          ReplyAnswer(values: <String>["Yes"]),
        ],
      ),
    ).called(1);
    verify(() => api.rejectQuestion(requestId: "question-1")).called(1);
  });

  test("sendMessage builds text and fileData parts from attachments", () async {
    final api = MockSessionApi();
    final repository = SessionRepository(api: api);

    when(
      () => api.sendMessage(
        sessionId: any(named: "sessionId"),
        parts: any(named: "parts"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        command: any(named: "command"),
      ),
    ).thenAnswer((_) async => ApiResponse<void>.success(null));

    await repository.sendMessage(
      sessionId: "session-1",
      text: "look at this",
      attachments: [
        PickedMedia(bytes: Uint8List.fromList([1, 2, 3]), mimeType: "image/png", filename: "shot.png"),
      ],
      agent: null,
      model: null,
      variant: null,
      command: null,
    );

    final captured = verify(
      () => api.sendMessage(
        sessionId: "session-1",
        parts: captureAny(named: "parts"),
        agent: null,
        model: null,
        variant: null,
        command: null,
      ),
    ).captured.single as List<PromptPart>;

    expect(captured, hasLength(2));
    expect(captured[0], isA<PromptPartText>());
    expect(captured[1], isA<PromptPartFileData>());
    expect((captured[1] as PromptPartFileData).mime, equals("image/png"));
  });

  test("sendMessage omits the text part when text is empty (attachment-only)", () async {
    final api = MockSessionApi();
    final repository = SessionRepository(api: api);

    when(
      () => api.sendMessage(
        sessionId: any(named: "sessionId"),
        parts: any(named: "parts"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        command: any(named: "command"),
      ),
    ).thenAnswer((_) async => ApiResponse<void>.success(null));

    await repository.sendMessage(
      sessionId: "session-1",
      text: "",
      attachments: [
        PickedMedia(bytes: Uint8List.fromList([9]), mimeType: "image/jpeg", filename: null),
      ],
      agent: null,
      model: null,
      variant: null,
      command: null,
    );

    final captured = verify(
      () => api.sendMessage(
        sessionId: "session-1",
        parts: captureAny(named: "parts"),
        agent: null,
        model: null,
        variant: null,
        command: null,
      ),
    ).captured.single as List<PromptPart>;

    expect(captured, hasLength(1));
    expect(captured.single, isA<PromptPartFileData>());
  });
}
