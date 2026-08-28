import "dart:async";
import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:http/http.dart" as http;
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/api/models/voice_capabilities_api_model.dart";
import "package:test/test.dart";

class _RecordingAuthClient() extends Mock implements AuthenticatedHttpApiClient {
  final List<Map<String, String>?> fields = [];
  Duration? timeout;
  bool hang = false;

  @override
  Future<ApiResponse<T>> postMultipart<T>(
    Uri url, {
    required T Function(dynamic json) fromJson,
    required Future<List<http.MultipartFile>> Function() createFiles,
    Map<String, String>? headers,
    Map<String, String>? fields,
    Duration? timeout,
  }) async {
    this.fields.add(fields);
    this.timeout = timeout;
    if (hang) return await Completer<ApiResponse<T>>().future;
    return ApiResponse.success(fromJson({"text": "ok"}));
  }
}

class _RecordingPublicClient() extends Mock implements HttpApiClient {
  Object? responseJson;
  ApiError? error;
  bool hang = false;
  Uri? lastUrl;

  @override
  Future<ApiResponse<T>> get<T>(
    Uri url, {
    required T Function(dynamic json) fromJson,
    Map<String, String>? headers,
    ContentType? contentType,
    bool logBody = false,
  }) async {
    lastUrl = url;
    if (hang) return await Completer<ApiResponse<T>>().future;
    final error = this.error;
    if (error != null) return ApiResponse.error(error);
    return ApiResponse.success(fromJson(responseJson));
  }
}

void main() {
  late _RecordingAuthClient authClient;
  late _RecordingPublicClient publicClient;
  late VoiceApi api;

  setUp(() {
    authClient = _RecordingAuthClient();
    publicClient = _RecordingPublicClient();
    api = VoiceApi(authClient, publicClient);
  });

  test("capability API parses the exact endpoint payload without choosing a product mode", () async {
    publicClient.responseJson = {
      "realtime": {
        "enabled": true,
        "protocolVersions": [1],
      },
    };

    final result = await api.discoverCapabilities();

    expect(publicClient.lastUrl, Uri.parse("$authBaseUrl/voice/capabilities"));
    expect(
      result,
      isA<SuccessResponse<VoiceCapabilitiesApiModel>>()
          .having((response) => response.data.realtimeEnabled, "enabled", isTrue)
          .having((response) => response.data.protocolVersions, "versions", [1]),
    );
  });

  test("capability API preserves endpoint failures for repository policy", () async {
    final error = ApiError.nonSuccessCode(errorCode: 404, rawErrorString: "missing");
    publicClient.error = error;

    final result = await api.discoverCapabilities();

    expect(
      result,
      isA<ErrorResponse<VoiceCapabilitiesApiModel>>().having((value) => value.error, "error", same(error)),
    );
  });

  test("capability timeout becomes a typed API transport failure", () {
    fakeAsync((async) {
      publicClient.hang = true;
      ApiResponse<VoiceCapabilitiesApiModel>? result;
      api.discoverCapabilities().then((value) => result = value);

      async.elapse(const Duration(seconds: 4));
      async.flushMicrotasks();
      expect(result, isNull);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(result, isA<ErrorResponse<VoiceCapabilitiesApiModel>>());
    });
  });

  test("malformed capability payload becomes a typed parsing failure", () async {
    publicClient.responseJson = {
      "realtime": {
        "enabled": true,
        "protocolVersions": [2, "bad"],
      },
    };

    final result = await api.discoverCapabilities();

    expect(
      result,
      isA<ErrorResponse<VoiceCapabilitiesApiModel>>().having(
        (value) => value.error,
        "error",
        isA<JsonParsingError>(),
      ),
    );
  });

  test("hung async upload is bounded at exactly 120 seconds", () {
    fakeAsync((async) {
      authClient.hang = true;
      VoiceTranscriptionApiResult? result;
      api
          .transcribe(
            audioFilePath: "test/fixtures/voice_realtime_protocol_v1.json",
            mimeType: "application/json",
            projectKey: null,
          )
          .then((value) => result = value);

      async.elapse(const Duration(seconds: 119));
      async.flushMicrotasks();
      expect(result, isNull);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(result, isA<VoiceTranscriptionApiFailure>());
    });
  });

  test("async upload sends an already-authorized opaque project key", () async {
    final projectKey = deriveProjectGlossaryKey(projectId: "project-123");

    await api.transcribe(
      audioFilePath: "test/fixtures/voice_realtime_protocol_v1.json",
      mimeType: "application/json",
      projectKey: projectKey,
    );

    expect(authClient.timeout, const Duration(seconds: 120));
    expect(authClient.fields.single, {"projectKey": projectKey});
    expect(authClient.fields.single.toString(), isNot(contains("project-123")));
  });

  test("async upload omits absent project context and rejects a raw project id", () async {
    await api.transcribe(
      audioFilePath: "test/fixtures/voice_realtime_protocol_v1.json",
      mimeType: "application/json",
      projectKey: null,
    );
    expect(authClient.fields.single, isNull);

    await expectLater(
      api.transcribe(
        audioFilePath: "test/fixtures/voice_realtime_protocol_v1.json",
        mimeType: "application/json",
        projectKey: "project-123",
      ),
      throwsArgumentError,
    );
  });
}
