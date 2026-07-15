import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/api/project_api.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockRelayHttpApiClient extends Mock implements RelayHttpApiClient {}

void main() {
  group("ProjectApi.listProjects", () {
    late MockRelayHttpApiClient client;
    late ProjectApi api;

    setUp(() {
      client = MockRelayHttpApiClient();
      api = ProjectApi(client: client);
    });

    test("returns projects from GET /projects", () async {
      const projects = Projects(
        data: [
          Project(id: "project-1", name: "Project 1", path: "/project-1", time: null),
        ],
      );
      when(
        () => client.get<Projects>("/projects", fromJson: any(named: "fromJson")),
      ).thenAnswer((_) async => ApiResponse.success(projects));

      final response = await api.listProjects();

      expect(response, ApiResponse<Projects>.success(projects));
      verify(
        () => client.get<Projects>("/projects", fromJson: any(named: "fromJson")),
      ).called(1);
    });

    test("propagates GET /projects errors", () async {
      final error = ApiError.generic();
      when(
        () => client.get<Projects>("/projects", fromJson: any(named: "fromJson")),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final response = await api.listProjects();

      expect(response, ApiResponse<Projects>.error(error));
      verify(
        () => client.get<Projects>("/projects", fromJson: any(named: "fromJson")),
      ).called(1);
    });
  });
}
