import "package:http/http.dart" as http;
import "package:sesori_bridge/src/api/app_client_status_response.dart";
import "package:sesori_bridge/src/api/generate_session_metadata_response.dart";
import "package:sesori_bridge/src/api/sesori_server_api.dart";
import "package:sesori_bridge/src/repositories/session_metadata_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("SessionMetadataRepository", () {
    test("passes messages through unchanged up to 500 characters", () async {
      final api = _FakeSesoriServerApi();
      final repository = SessionMetadataRepository(api: api);
      final message = "x" * 500;

      final metadata = await repository.generateMetadata(firstMessage: message);

      expect(metadata, (title: "Generated title", branchName: "generated-branch"));
      expect(api.requests.single, equals(GenerateSessionMetadataRequest(firstMessage: message)));
      expect(api.abortSignals.single.isAborted, isFalse);
    });

    test("truncates messages longer than 500 characters", () async {
      final api = _FakeSesoriServerApi();
      final repository = SessionMetadataRepository(api: api);

      await repository.generateMetadata(firstMessage: "x" * 501);

      expect(api.requests.single.firstMessage, equals("x" * 500));
    });

    test("does not split a surrogate pair at the 500-code-unit boundary", () async {
      final api = _FakeSesoriServerApi();
      final repository = SessionMetadataRepository(api: api);

      await repository.generateMetadata(firstMessage: "${"x" * 499}😀tail");

      expect(api.requests.single.firstMessage, equals("x" * 499));
    });

    test("translates HTTP aborts at the repository boundary", () async {
      final abort = http.RequestAbortedException(Uri.parse("https://auth.example.test/metadata"));
      final repository = SessionMetadataRepository(api: _FakeSesoriServerApi(failure: abort));

      await expectLater(
        repository.generateMetadata(firstMessage: "message"),
        throwsA(
          isA<SessionMetadataRequestAbortedException>().having(
            (error) => error.innerError,
            "innerError",
            same(abort),
          ),
        ),
      );
    });

    test("translates invalid API responses while preserving their cause", () async {
      const innerError = FormatException("invalid metadata response");
      final innerStackTrace = StackTrace.fromString("inner metadata response stack");
      final apiError = SesoriServerApiResponseException(
        method: "POST",
        uri: Uri.parse("https://auth.example.test/metadata"),
        innerError: innerError,
        innerStackTrace: innerStackTrace,
      );
      final repository = SessionMetadataRepository(api: _FakeSesoriServerApi(failure: apiError));

      await expectLater(
        repository.generateMetadata(firstMessage: "message"),
        throwsA(
          isA<SessionMetadataInvalidResponseException>()
              .having((error) => error.cause, "cause", same(apiError))
              .having((error) => error.causeStackTrace, "causeStackTrace", isNot(StackTrace.empty))
              .having((error) => error.innerError, "innerError", same(innerError))
              .having((error) => error.innerStackTrace, "innerStackTrace", same(innerStackTrace)),
        ),
      );
    });

    test("surfaces API failure unchanged", () async {
      const error = FormatException("invalid response");
      final repository = SessionMetadataRepository(api: _FakeSesoriServerApi(failure: error));

      await expectLater(
        repository.generateMetadata(firstMessage: "message"),
        throwsA(same(error)),
      );
    });

    test("aborts pending API requests when shutdown begins", () async {
      final api = _FakeSesoriServerApi();
      final repository = SessionMetadataRepository(api: api);

      await repository.generateMetadata(firstMessage: "message");
      repository.beginShutdown();

      expect(api.abortSignals.single.isAborted, isTrue);
    });
  });
}

class _FakeSesoriServerApi({final Object? failure}) implements SesoriServerApi {
  final Object? error = failure;

  final List<GenerateSessionMetadataRequest> requests = [];
  final List<SesoriServerRequestAbortSignal> abortSignals = [];

  @override
  Future<GenerateSessionMetadataResponse> generateSessionMetadata({
    required GenerateSessionMetadataRequest request,
    required SesoriServerRequestAbortSignal abortSignal,
  }) async {
    requests.add(request);
    abortSignals.add(abortSignal);
    if (error case final error?) throw error;
    return const GenerateSessionMetadataResponse(title: "Generated title", branchName: "generated-branch");
  }

  @override
  Future<AppClientStatusResponse> getAppClientStatus({required String accessToken}) => throw UnimplementedError();
}
