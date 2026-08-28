import "package:http/http.dart" as http;
import "package:sesori_bridge/src/api/models/app_client_status_response.dart";
import "package:sesori_bridge/src/api/models/generate_session_metadata_response.dart";
import "package:sesori_bridge/src/api/models/project_glossary_response.dart";
import "package:sesori_bridge/src/api/sesori_server_api.dart";
import "package:sesori_bridge/src/foundation/abortable_request.dart";
import "package:sesori_bridge/src/repositories/project_glossary_publication_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  final projectKey = ProjectGlossaryKey.parse(
    value: "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
  );

  group("ProjectGlossaryPublicationRepository", () {
    test("maps typed list, add, and remove responses", () async {
      final api = _FakeSesoriServerApi();
      final repository = ProjectGlossaryPublicationRepository(api: api);
      final repositoryScope = ProjectGlossaryScope.repository(projectKey: projectKey);
      final localScope = ProjectGlossaryScope.bridgeLocal(projectKey: projectKey, bridgeId: "bridge-1");

      expect(await repository.getWords(projectKey: projectKey), ["Existing"]);
      expect(
        await repository.addWords(scope: repositoryScope, words: const ["Sesori"]),
        ["Sesori"],
      );
      expect(
        await repository.removeWords(scope: localScope, words: const ["Obsolete"]),
        1,
      );

      expect(api.listProjectKeys, [projectKey]);
      expect(
        api.addRequests,
        [
          ProjectGlossaryWordsRequest(scope: repositoryScope, words: const ["Sesori"]),
        ],
      );
      expect(
        api.removeRequests,
        [
          ProjectGlossaryWordsRequest(scope: localScope, words: const ["Obsolete"]),
        ],
      );
      expect(api.abortSignals, everyElement(same(api.abortSignals.first)));
      expect(api.abortSignals.first.isAborted, isFalse);
    });

    test("aborts every hosted glossary operation when shutdown begins", () async {
      final api = _FakeSesoriServerApi();
      final repository = ProjectGlossaryPublicationRepository(api: api);

      await repository.getWords(projectKey: projectKey);
      repository.beginShutdown();

      expect(api.abortSignals.single.isAborted, isTrue);
    });

    test("translates HTTP aborts while preserving the transport error", () async {
      final abort = http.RequestAbortedException(
        Uri.parse("https://auth.example.test/voice/glossary"),
      );
      final repository = ProjectGlossaryPublicationRepository(
        api: _FakeSesoriServerApi(failure: abort),
      );

      await expectLater(
        repository.getWords(projectKey: projectKey),
        throwsA(
          isA<ProjectGlossaryPublicationAbortedException>()
              .having((error) => error.innerError, "innerError", same(abort))
              .having((error) => error.innerStackTrace, "innerStackTrace", isNot(StackTrace.empty)),
        ),
      );
    });

    test("surfaces non-abort transport failures unchanged", () async {
      const error = FormatException("invalid glossary response");
      final repository = ProjectGlossaryPublicationRepository(
        api: _FakeSesoriServerApi(failure: error),
      );

      await expectLater(repository.getWords(projectKey: projectKey), throwsA(same(error)));
    });
  });
}

class _FakeSesoriServerApi({final Object? failure}) implements SesoriServerApi {
  final Object? error = failure;
  final List<ProjectGlossaryKey> listProjectKeys = [];
  final List<ProjectGlossaryWordsRequest> addRequests = [];
  final List<ProjectGlossaryWordsRequest> removeRequests = [];
  final List<AbortSignal> abortSignals = [];

  @override
  Future<ProjectGlossaryWordsResponse> getProjectGlossary({
    required ProjectGlossaryKey projectKey,
    required AbortSignal abortSignal,
  }) async {
    listProjectKeys.add(projectKey);
    abortSignals.add(abortSignal);
    if (error case final error?) throw error;
    return const ProjectGlossaryWordsResponse(words: ["Existing"]);
  }

  @override
  Future<ProjectGlossaryAddedWordsResponse> addProjectGlossaryWords({
    required ProjectGlossaryWordsRequest request,
    required AbortSignal abortSignal,
  }) async {
    addRequests.add(request);
    abortSignals.add(abortSignal);
    if (error case final error?) throw error;
    return const ProjectGlossaryAddedWordsResponse(added: ["Sesori"]);
  }

  @override
  Future<ProjectGlossaryRemovedWordsResponse> removeProjectGlossaryWords({
    required ProjectGlossaryWordsRequest request,
    required AbortSignal abortSignal,
  }) async {
    removeRequests.add(request);
    abortSignals.add(abortSignal);
    if (error case final error?) throw error;
    return const ProjectGlossaryRemovedWordsResponse(removed: 1);
  }

  @override
  Future<AppClientStatusResponse> getAppClientStatus({required String accessToken}) => throw UnimplementedError();

  @override
  Future<GenerateSessionMetadataResponse> generateSessionMetadata({
    required GenerateSessionMetadataRequest request,
    required AbortSignal abortSignal,
  }) => throw UnimplementedError();
}
