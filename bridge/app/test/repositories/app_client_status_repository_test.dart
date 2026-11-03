import "package:sesori_bridge/src/api/models/app_client_status_response.dart";
import "package:sesori_bridge/src/api/models/generate_session_metadata_response.dart";
import "package:sesori_bridge/src/api/models/project_glossary_response.dart";
import "package:sesori_bridge/src/api/sesori_server_api.dart";
import "package:sesori_bridge/src/foundation/abortable_request.dart";
import "package:sesori_bridge/src/repositories/app_client_status_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("AppClientStatusRepository", () {
    test("maps strict true and false responses", () async {
      final api = _FakeSesoriServerApi();
      final repository = AppClientStatusRepository(api: api);

      api.response = const AppClientStatusResponse(registered: true);
      expect(await repository.getStatus(accessToken: "token"), isA<AppClientRegistered>());

      api.response = const AppClientStatusResponse(registered: false);
      expect(await repository.getStatus(accessToken: "token"), isA<AppClientAbsent>());
      expect(api.accessTokens, equals(["token", "token"]));
    });

    test("maps transport and malformed-response failures to unavailable", () async {
      const error = FormatException("bad body");
      final api = _FakeSesoriServerApi()..error = error;

      final result = await AppClientStatusRepository(
        api: api,
      ).getStatus(accessToken: "token");

      expect(result, isA<AppClientStatusUnavailable>());
      expect((result as AppClientStatusUnavailable).error, same(error));
    });
  });
}

class _FakeSesoriServerApi() implements SesoriServerApi {
  AppClientStatusResponse response = const AppClientStatusResponse(registered: false);
  Object? error;
  final List<String> accessTokens = [];

  @override
  Future<AppClientStatusResponse> getAppClientStatus({required String accessToken}) async {
    accessTokens.add(accessToken);
    if (error case final failure?) throw failure;
    return response;
  }

  @override
  Future<GenerateSessionMetadataResponse> generateSessionMetadata({
    required GenerateSessionMetadataRequest request,
    required AbortSignal abortSignal,
  }) => throw UnimplementedError();

  @override
  Future<ProjectGlossaryWordsResponse> getProjectGlossary({
    required ProjectGlossaryKey projectKey,
    required AbortSignal abortSignal,
  }) => throw UnimplementedError();

  @override
  Future<ProjectGlossaryAddedWordsResponse> addProjectGlossaryWords({
    required ProjectGlossaryWordsRequest request,
    required AbortSignal abortSignal,
  }) => throw UnimplementedError();

  @override
  Future<ProjectGlossaryRemovedWordsResponse> removeProjectGlossaryWords({
    required ProjectGlossaryWordsRequest request,
    required AbortSignal abortSignal,
  }) => throw UnimplementedError();
}
