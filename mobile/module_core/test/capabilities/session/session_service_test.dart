import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockRelayHttpApiClient extends Mock implements RelayHttpApiClient {}

void main() {
  group("SessionService", () {
    late MockRelayHttpApiClient mockClient;
    late SessionService service;

    setUp(() {
      mockClient = MockRelayHttpApiClient();
      service = SessionService(mockClient);
    });

    test("createSessionWithMessage sends dedicatedWorktree in request body", () async {
      const session = Session(
        id: "s1",
        projectID: "p1",
        directory: "/tmp/project",
        parentID: null,
        title: "Session",
        summary: null,
        time: SessionTime(created: 1, updated: 1, archived: null),
        pullRequest: null,
      );

      when(
        () => mockClient.post<Session>(
          "/session/create",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(session));

      final result = await service.createSessionWithMessage(
        projectId: "p1",
        text: "hello",
        agent: null,
        model: null,
        dedicatedWorktree: true,
      );

      expect(result, isA<SuccessResponse<Session>>());
      verify(
        () => mockClient.post<Session>(
          "/session/create",
          fromJson: any(named: "fromJson"),
          body: const CreateSessionRequest(
            projectId: "p1",
            parts: [PromptPart.text(text: "hello")],
            agent: null,
            model: null,
            command: null,
            dedicatedWorktree: true,
          ),
        ),
      ).called(1);
    });

    test("listCommands sends project header when projectId is provided", () async {
      when(
        () => mockClient.get<CommandListResponse>(
          "/command",
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const CommandListResponse(
            items: <CommandInfo>[
              CommandInfo(name: "review", template: "/review", hints: <String>["file.dart"], provider: null),
            ],
          ),
        ),
      );

      final result = await service.listCommands(projectId: "/repo");

      expect(result, isA<SuccessResponse<CommandListResponse>>());
      verify(
        () => mockClient.get<CommandListResponse>(
          "/command",
          fromJson: any(named: "fromJson"),
          headers: const {"x-project-id": "/repo"},
        ),
      ).called(1);
    });

    test("createEmptySession sends an empty parts list", () async {
      const session = Session(
        id: "s-empty",
        projectID: "p1",
        directory: "/tmp/project",
        parentID: null,
        title: "Session",
        summary: null,
        time: SessionTime(created: 1, updated: 1, archived: null),
      );

      when(
        () => mockClient.post<Session>(
          "/session/create",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(session));

      final result = await service.createEmptySession(
        projectId: "p1",
        agent: null,
        model: null,
        dedicatedWorktree: true,
      );

      expect(result, isA<SuccessResponse<Session>>());
      verify(
        () => mockClient.post<Session>(
          "/session/create",
          fromJson: any(named: "fromJson"),
          body: const CreateSessionRequest(
            projectId: "p1",
            parts: <PromptPart>[],
            agent: null,
            model: null,
            command: null,
            dedicatedWorktree: true,
          ),
        ),
      ).called(1);
    });

    test("sendCommand posts the command body to the session command route", () async {
      when(
        () => mockClient.post<void>(
          "/session/s1/command",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));

      final result = await service.sendCommand(
        sessionId: "s1",
        command: "review",
        arguments: "lib/main.dart",
      );

      expect(result, isA<SuccessResponse<void>>());
      verify(
        () => mockClient.post<void>(
          "/session/s1/command",
          fromJson: any(named: "fromJson"),
          body: const SendCommandRequest(
            sessionId: "s1",
            command: "review",
            arguments: "lib/main.dart",
          ),
        ),
      ).called(1);
    });

    test("archiveSession sends cleanup options in request body", () async {
      const session = Session(
        id: "s1",
        projectID: "p1",
        directory: "/tmp/project",
        parentID: null,
        title: "Session",
        summary: null,
        time: SessionTime(created: 1, updated: 1, archived: null),
        pullRequest: null,
      );

      when(
        () => mockClient.patch<Session>(
          "/session/update/archive",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(session));

      await service.archiveSession(
        sessionId: "s1",
        deleteWorktree: true,
        deleteBranch: false,
        force: true,
      );

      verify(
        () => mockClient.patch<Session>(
          "/session/update/archive",
          fromJson: any(named: "fromJson"),
          body: const UpdateSessionArchiveRequest(
            sessionId: "s1",
            archived: true,
            deleteWorktree: true,
            deleteBranch: false,
            force: true,
          ),
        ),
      ).called(1);
    });

    test("deleteSession sends DeleteSessionRequest as DELETE body", () async {
      when(
        () => mockClient.delete<SuccessEmptyResponse>(
          "/session/delete",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(const SuccessEmptyResponse()));

      await service.deleteSession(
        sessionId: "s1",
        deleteWorktree: true,
        deleteBranch: true,
        force: false,
      );

      verify(
        () => mockClient.delete<SuccessEmptyResponse>(
          "/session/delete",
          fromJson: any(named: "fromJson"),
          body: const DeleteSessionRequest(
            sessionId: "s1",
            deleteWorktree: true,
            deleteBranch: true,
            force: false,
          ),
        ),
      ).called(1);
    });

    test("deleteSession throws SessionCleanupRejectedException on 409", () async {
      const rejection = SessionCleanupRejection(
        issues: [CleanupIssue.unstagedChanges()],
      );

      when(
        () => mockClient.delete<SuccessEmptyResponse>(
          "/session/delete",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.error(
          ApiError.nonSuccessCode(
            errorCode: 409,
            rawErrorString: jsonEncode(rejection.toJson()),
          ),
        ),
      );

      await expectLater(
        () => service.deleteSession(
          sessionId: "s1",
          deleteWorktree: true,
          deleteBranch: true,
          force: false,
        ),
        throwsA(
          isA<SessionCleanupRejectedException>().having(
            (error) => error.rejection,
            "rejection",
            rejection,
          ),
        ),
      );
    });
  });
}
