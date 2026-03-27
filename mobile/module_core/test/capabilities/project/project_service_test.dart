import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockRelayHttpApiClient extends Mock implements RelayHttpApiClient {}

void main() {
  group("ProjectService", () {
    late MockRelayHttpApiClient mockClient;
    late ProjectService service;

    setUp(() {
      mockClient = MockRelayHttpApiClient();
      service = ProjectService(mockClient);
    });

    // -------------------------------------------------------------------------
    // 1. createProject sends POST /project with body {"path": "<value>"}
    // -------------------------------------------------------------------------

    test("createProject sends POST /project with correct body", () async {
      const mockProject = Project(
        id: "proj-1",
        name: "My Project",
        time: ProjectTime(created: 1000, updated: 2000),
      );

      when(
        () => mockClient.post<Project>(
          "/project/create",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(mockProject));

      final result = await service.createProject(path: "/home/user/project");

      expect(result, isA<SuccessResponse<Project>>());
      expect((result as SuccessResponse<Project>).data, equals(mockProject));

      verify(
        () => mockClient.post<Project>(
          "/project/create",
          fromJson: any(named: "fromJson"),
          body: {"path": "/home/user/project"},
        ),
      ).called(1);
    });

    // -------------------------------------------------------------------------
    // 2. discoverProject sends POST /project/discover with body {"path": "<value>"}
    // -------------------------------------------------------------------------

    test("discoverProject sends POST /project/discover with correct body", () async {
      const mockProject = Project(
        id: "proj-2",
        name: "Discovered Project",
        time: ProjectTime(created: 1000, updated: 2000),
      );

      when(
        () => mockClient.post<Project>(
          "/project/open",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(mockProject));

      final result = await service.discoverProject(path: "/home/user/discovered");

      expect(result, isA<SuccessResponse<Project>>());
      expect((result as SuccessResponse<Project>).data, equals(mockProject));

      verify(
        () => mockClient.post<Project>(
          "/project/open",
          fromJson: any(named: "fromJson"),
          body: {"path": "/home/user/discovered"},
        ),
      ).called(1);
    });

    // -------------------------------------------------------------------------
    // 3. getFilesystemSuggestions sends GET /filesystem/suggestions?prefix=<value>
    // -------------------------------------------------------------------------

    test("getFilesystemSuggestions sends GET with correct query params", () async {
      const mockSuggestions = [
        FilesystemSuggestion(
          path: "/home/user/project1",
          name: "project1",
          isGitRepo: true,
        ),
        FilesystemSuggestion(
          path: "/home/user/project2",
          name: "project2",
          isGitRepo: false,
        ),
      ];

      when(
        () => mockClient.get<List<FilesystemSuggestion>>(
          "/filesystem/suggestions",
          fromJson: any(named: "fromJson"),
          queryParameters: any(named: "queryParameters"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(mockSuggestions));

      final result = await service.getFilesystemSuggestions(prefix: "/home/user");

      expect(result, isA<SuccessResponse<List<FilesystemSuggestion>>>());
      expect(
        (result as SuccessResponse<List<FilesystemSuggestion>>).data,
        equals(mockSuggestions),
      );

      verify(
        () => mockClient.get<List<FilesystemSuggestion>>(
          "/filesystem/suggestions",
          fromJson: any(named: "fromJson"),
          queryParameters: {"prefix": "/home/user"},
        ),
      ).called(1);
    });

    // -------------------------------------------------------------------------
    // 3b. hideProject sends POST /project/hide with projectId in body
    // -------------------------------------------------------------------------

    test("hideProject sends POST /project/hide with projectId in body", () async {
      when(
        () => mockClient.post<void>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));

      final result = await service.hideProject(projectId: "proj-1");

      expect(result, isA<SuccessResponse<void>>());

      verify(
        () => mockClient.post<void>(
          "/project/hide",
          fromJson: any(named: "fromJson"),
          body: {"projectId": "proj-1"},
        ),
      ).called(1);
    });

    test("hideProject error response maps to ErrorResponse", () async {
      final error = ApiError.generic();
      when(
        () => mockClient.post<void>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final result = await service.hideProject(projectId: "proj-1");

      expect(result, isA<ErrorResponse<void>>());
      expect((result as ErrorResponse<void>).error, equals(error));
    });

    // -------------------------------------------------------------------------
    // 4. createProject error response maps to ErrorResponse correctly
    // -------------------------------------------------------------------------

    test("createProject error response maps to ErrorResponse", () async {
      final error = ApiError.generic();
      when(
        () => mockClient.post<Project>(
          "/project/create",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final result = await service.createProject(path: "/home/user/project");

      expect(result, isA<ErrorResponse<Project>>());
      expect((result as ErrorResponse<Project>).error, equals(error));
    });

    // -------------------------------------------------------------------------
    // 5. discoverProject error response maps to ErrorResponse correctly
    // -------------------------------------------------------------------------

    test("discoverProject error response maps to ErrorResponse", () async {
      final error = ApiError.generic();
      when(
        () => mockClient.post<Project>(
          "/project/open",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final result = await service.discoverProject(path: "/home/user/project");

      expect(result, isA<ErrorResponse<Project>>());
      expect((result as ErrorResponse<Project>).error, equals(error));
    });

    // -------------------------------------------------------------------------
    // 6. getFilesystemSuggestions error response maps to ErrorResponse
    // -------------------------------------------------------------------------

    test("getFilesystemSuggestions error response maps to ErrorResponse", () async {
      final error = ApiError.generic();
      when(
        () => mockClient.get<List<FilesystemSuggestion>>(
          "/filesystem/suggestions",
          fromJson: any(named: "fromJson"),
          queryParameters: any(named: "queryParameters"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final result = await service.getFilesystemSuggestions(prefix: "/home/user");

      expect(result, isA<ErrorResponse<List<FilesystemSuggestion>>>());
      expect((result as ErrorResponse<List<FilesystemSuggestion>>).error, equals(error));
    });

    // -------------------------------------------------------------------------
    // 7. renameProject sends PATCH /project/{id}/name with correct body
    // -------------------------------------------------------------------------

    test("renameProject sends PATCH /project/{id}/name with correct body", () async {
      const mockProject = Project(
        id: "proj-1",
        name: "New Name",
        time: ProjectTime(created: 1000, updated: 2000),
      );

      when(
        () => mockClient.patch<Project>(
          "/project/proj-1/name",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(mockProject));

      final result = await service.renameProject(projectId: "proj-1", name: "New Name");

      expect(result, isA<SuccessResponse<Project>>());
      expect((result as SuccessResponse<Project>).data, equals(mockProject));

      verify(
        () => mockClient.patch<Project>(
          "/project/proj-1/name",
          fromJson: any(named: "fromJson"),
          body: RenameProjectRequest(name: "New Name").toJson(),
        ),
      ).called(1);
    });

    test("renameProject error response maps to ErrorResponse", () async {
      final error = ApiError.generic();
      when(
        () => mockClient.patch<Project>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final result = await service.renameProject(projectId: "proj-1", name: "New Name");

      expect(result, isA<ErrorResponse<Project>>());
      expect((result as ErrorResponse<Project>).error, equals(error));
    });
  });
}
