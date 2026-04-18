import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/repositories/slash_command_repository.dart";
import "package:sesori_dart_core/src/services/slash_command_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockSlashCommandRepository extends Mock implements SlashCommandRepository {}

void main() {
  group("SlashCommandService", () {
    late MockSlashCommandRepository mockRepository;
    late SlashCommandService service;

    setUp(() {
      mockRepository = MockSlashCommandRepository();
      service = SlashCommandService(repository: mockRepository);
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

    test("createSessionWithMessage clears agent and model when command is present", () async {
      when(
        () => mockRepository.createSessionWithMessage(
          projectId: any(named: "projectId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
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
        command: "review",
        dedicatedWorktree: true,
      );

      verify(
        () => mockRepository.createSessionWithMessage(
          projectId: "project-1",
          text: "lib/main.dart",
          agent: null,
          model: null,
          command: "review",
          dedicatedWorktree: true,
        ),
      ).called(1);
    });

    test("sendMessage clears agent and model when command is present", () async {
      when(
        () => mockRepository.sendMessage(
          sessionId: any(named: "sessionId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          providerID: any(named: "providerID"),
          modelID: any(named: "modelID"),
          command: any(named: "command"),
        ),
      ).thenAnswer((_) async => ApiResponse<void>.success(null));

      await service.sendMessage(
        sessionId: "session-1",
        text: "lib/main.dart",
        agent: "build",
        providerID: "openai",
        modelID: "gpt-4.1",
        command: "review",
      );

      verify(
        () => mockRepository.sendMessage(
          sessionId: "session-1",
          text: "lib/main.dart",
          agent: null,
          providerID: null,
          modelID: null,
          command: "review",
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
