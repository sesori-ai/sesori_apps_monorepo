import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/api/filesystem_api.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockRelayHttpApiClient extends Mock implements RelayHttpApiClient {}

void main() {
  late MockRelayHttpApiClient client;
  late FilesystemApi api;

  setUp(() {
    client = MockRelayHttpApiClient();
    api = FilesystemApi(client: client);
  });

  test("posts the prefix and fixed result limit", () async {
    const suggestions = FilesystemSuggestions(
      data: [
        FilesystemSuggestion(path: "/project-1", name: "project-1", isGitRepo: true),
      ],
    );
    when(
      () => client.post<FilesystemSuggestions>(
        "/filesystem/suggestions",
        fromJson: any(named: "fromJson"),
        body: any(named: "body"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(suggestions));

    final response = await api.getSuggestions(prefix: "/projects");

    expect(response, ApiResponse<FilesystemSuggestions>.success(suggestions));
    verify(
      () => client.post<FilesystemSuggestions>(
        "/filesystem/suggestions",
        fromJson: any(named: "fromJson"),
        body: const FilesystemSuggestionsRequest(prefix: "/projects", maxResults: 50),
      ),
    ).called(1);
  });

  test("propagates errors", () async {
    final error = ApiError.generic();
    when(
      () => client.post<FilesystemSuggestions>(
        "/filesystem/suggestions",
        fromJson: any(named: "fromJson"),
        body: any(named: "body"),
      ),
    ).thenAnswer((_) async => ApiResponse.error(error));

    final response = await api.getSuggestions(prefix: null);

    expect(response, ApiResponse<FilesystemSuggestions>.error(error));
  });
}
