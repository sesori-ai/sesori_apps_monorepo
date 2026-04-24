import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/session/session_service.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockSessionRepository extends Mock implements SessionRepository {}

void main() {
  group("SessionService", () {
    late MockSessionRepository mockRepository;
    late SessionService service;

    setUp(() {
      mockRepository = MockSessionRepository();
      service = SessionService(repository: mockRepository);
    });

    test("listCommands returns empty response without transport when projectId is null", () async {
      final result = await service.listCommands(projectId: null);

      expect(result, isA<SuccessResponse<CommandListResponse>>());
      expect((result as SuccessResponse<CommandListResponse>).data.items, isEmpty);
      verifyNever(() => mockRepository.listCommands(projectId: any(named: "projectId")));
    });

    test("listCommands trims projectId before repository call", () async {
      when(
        () => mockRepository.listCommands(projectId: any(named: "projectId")),
      ).thenAnswer((_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])));

      await service.listCommands(projectId: "  project-1  ");

      verify(() => mockRepository.listCommands(projectId: "project-1")).called(1);
    });

    test("createSessionWithMessage forwards raw variant", () async {
      when(
        () => mockRepository.createSessionWithMessage(
          projectId: any(named: "projectId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(_session()));

      await service.createSessionWithMessage(
        projectId: "project-1",
        text: "lib/main.dart",
        agent: "build",
        providerID: "openai",
        modelID: "gpt-4.1",
        variant: const SessionVariant(id: "custom-build"),
        command: "review",
        dedicatedWorktree: true,
      );

      verify(
        () => mockRepository.createSessionWithMessage(
          projectId: "project-1",
          text: "lib/main.dart",
          agent: "build",
          model: const PromptModel(providerID: "openai", modelID: "gpt-4.1"),
          variant: const SessionVariant(id: "custom-build"),
          command: "review",
          dedicatedWorktree: true,
        ),
      ).called(1);
    });

    test("sendMessage forwards raw variant", () async {
      when(
        () => mockRepository.sendMessage(
          sessionId: any(named: "sessionId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
        ),
      ).thenAnswer((_) async => ApiResponse<void>.success(null));

      await service.sendMessage(
        sessionId: "session-1",
        text: "lib/main.dart",
        agent: "build",
        providerID: "openai",
        modelID: "gpt-4.1",
        variant: const SessionVariant(id: "custom-build"),
        command: "review",
      );

      verify(
        () => mockRepository.sendMessage(
          sessionId: "session-1",
          text: "lib/main.dart",
          agent: "build",
          model: const PromptModel(providerID: "openai", modelID: "gpt-4.1"),
          variant: const SessionVariant(id: "custom-build"),
          command: "review",
        ),
      ).called(1);
    });

    test("sendMessage preserves agent model and variant when command is present", () async {
      when(
        () => mockRepository.sendMessage(
          sessionId: any(named: "sessionId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
        ),
      ).thenAnswer((_) async => ApiResponse<void>.success(null));

      await service.sendMessage(
        sessionId: "session-1",
        text: "lib/main.dart",
        agent: "build",
        providerID: "openai",
        modelID: "gpt-4.1",
        variant: const SessionVariant(id: "xhigh"),
        command: "review",
      );

      verify(
        () => mockRepository.sendMessage(
          sessionId: "session-1",
          text: "lib/main.dart",
          agent: "build",
          model: const PromptModel(providerID: "openai", modelID: "gpt-4.1"),
          variant: const SessionVariant(id: "xhigh"),
          command: "review",
        ),
      ).called(1);
    });

    test("sendMessage normalizes blank provider and model ids to null", () async {
      when(
        () => mockRepository.sendMessage(
          sessionId: any(named: "sessionId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
        ),
      ).thenAnswer((_) async => ApiResponse<void>.success(null));

      await service.sendMessage(
        sessionId: "session-1",
        text: "hello",
        agent: "build",
        providerID: "   ",
        modelID: "",
        variant: null,
        command: null,
      );

      verify(
        () => mockRepository.sendMessage(
          sessionId: "session-1",
          text: "hello",
          agent: "build",
          model: null,
          variant: null,
          command: null,
        ),
      ).called(1);
    });

    test("sendMessage treats blank command as null and preserves agent and model ids", () async {
      when(
        () => mockRepository.sendMessage(
          sessionId: any(named: "sessionId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
        ),
      ).thenAnswer((_) async => ApiResponse<void>.success(null));

      await service.sendMessage(
        sessionId: "session-1",
        text: "hello",
        agent: "build",
        providerID: "openai",
        modelID: "gpt-5.4",
        variant: const SessionVariant(id: "low"),
        command: "   ",
      );

      verify(
        () => mockRepository.sendMessage(
          sessionId: "session-1",
          text: "hello",
          agent: "build",
          model: const PromptModel(providerID: "openai", modelID: "gpt-5.4"),
          variant: const SessionVariant(id: "low"),
          command: null,
        ),
      ).called(1);
    });

    test("createSessionWithMessage treats blank command as null and preserves agent/model", () async {
      when(
        () => mockRepository.createSessionWithMessage(
          projectId: any(named: "projectId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(_session()));

      await service.createSessionWithMessage(
        projectId: "project-1",
        text: "hello",
        agent: "build",
        providerID: "openai",
        modelID: "gpt-5.4",
        variant: const SessionVariant(id: "xhigh"),
        command: "   ",
        dedicatedWorktree: false,
      );

      verify(
        () => mockRepository.createSessionWithMessage(
          projectId: "project-1",
          text: "hello",
          agent: "build",
          model: const PromptModel(providerID: "openai", modelID: "gpt-5.4"),
          variant: const SessionVariant(id: "xhigh"),
          command: null,
          dedicatedWorktree: false,
        ),
      ).called(1);
    });
  });
}

Session _session() {
  return const Session(
    id: "session-1",
    projectID: "project-1",
    directory: "/tmp/project-1",
    parentID: null,
    title: "Session",
    summary: null,
    time: SessionTime(created: 1, updated: 1, archived: null),
    pullRequest: null,
  );
}
