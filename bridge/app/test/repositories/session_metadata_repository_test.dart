import "dart:async";

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
      final shutdownSignal = Completer<void>().future;
      final message = "x" * 500;

      final title = await repository.generateTitle(firstMessage: message, shutdownSignal: shutdownSignal);

      expect(title, equals("Generated title"));
      expect(api.requests.single, equals(GenerateSessionMetadataRequest(firstMessage: message)));
      expect(api.shutdownSignals.single, same(shutdownSignal));
    });

    test("truncates messages longer than 500 characters", () async {
      final api = _FakeSesoriServerApi();
      final repository = SessionMetadataRepository(api: api);

      await repository.generateTitle(
        firstMessage: "x" * 501,
        shutdownSignal: Completer<void>().future,
      );

      expect(api.requests.single.firstMessage, equals("x" * 500));
    });

    test("does not split a surrogate pair at the 500-code-unit boundary", () async {
      final api = _FakeSesoriServerApi();
      final repository = SessionMetadataRepository(api: api);

      await repository.generateTitle(
        firstMessage: "${"x" * 499}😀tail",
        shutdownSignal: Completer<void>().future,
      );

      expect(api.requests.single.firstMessage, equals("x" * 499));
    });

    test("translates HTTP aborts at the repository boundary", () async {
      final abort = http.RequestAbortedException(Uri.parse("https://auth.example.test/metadata"));
      final repository = SessionMetadataRepository(api: _FakeSesoriServerApi(failure: abort));

      await expectLater(
        repository.generateTitle(firstMessage: "message", shutdownSignal: Completer<void>().future),
        throwsA(
          isA<SessionMetadataRequestAbortedException>().having(
            (error) => error.innerError,
            "innerError",
            same(abort),
          ),
        ),
      );
    });

    test("surfaces API failure unchanged", () async {
      const error = FormatException("invalid response");
      final repository = SessionMetadataRepository(api: _FakeSesoriServerApi(failure: error));

      await expectLater(
        repository.generateTitle(firstMessage: "message", shutdownSignal: Completer<void>().future),
        throwsA(same(error)),
      );
    });
  });
}

class _FakeSesoriServerApi({final Object? failure}) implements SesoriServerApi {
  final Object? error = failure;

  final List<GenerateSessionMetadataRequest> requests = [];
  final List<Future<void>> shutdownSignals = [];

  @override
  Future<GenerateSessionMetadataResponse> generateSessionMetadata({
    required GenerateSessionMetadataRequest request,
    required Future<void> shutdownSignal,
  }) async {
    requests.add(request);
    shutdownSignals.add(shutdownSignal);
    if (error case final error?) throw error;
    return const GenerateSessionMetadataResponse(title: "Generated title");
  }

  @override
  Future<AppClientStatusResponse> getAppClientStatus({required String accessToken}) => throw UnimplementedError();
}
