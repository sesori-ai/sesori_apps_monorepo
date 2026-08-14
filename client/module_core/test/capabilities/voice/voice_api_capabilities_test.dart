import "dart:async";
import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:http/http.dart" as http;
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
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

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    authClient = _RecordingAuthClient();
    publicClient = _RecordingPublicClient();
    api = VoiceApi(authClient, publicClient);
  });

  test("Given valid capabilities When discovering voice support Then parses exact protocol response", () async {
    publicClient.responseJson = {
      "realtime": {
        "enabled": true,
        "protocolVersions": [1],
      },
    };

    final result = await api.discoverCapabilities();

    expect(publicClient.lastUrl, Uri.parse("$authBaseUrl/voice/capabilities"));
    expect(result, isA<VoiceCapabilitiesAvailable>());
    final capabilities = (result as VoiceCapabilitiesAvailable).capabilities;
    expect(capabilities.realtimeEnabled, isTrue);
    expect(capabilities.supportsProtocol1, isTrue);
  });

  test(
    "Given old or unavailable capability endpoint When discovering voice support Then selects async fallback",
    () async {
      for (final error in [
        ApiError.nonSuccessCode(errorCode: 404, rawErrorString: "missing"),
        ApiError.dartHttpClient(const SocketException("offline")),
        ApiError.nonSuccessCode(errorCode: 500, rawErrorString: "failed"),
      ]) {
        publicClient.error = error;

        final result = await api.discoverCapabilities();

        expect(result, isA<VoiceCapabilitiesAsyncFallback>());
      }
    },
  );

  test(
    "Given malformed advertised capabilities When discovering voice support Then returns typed contract failure",
    () async {
      publicClient.responseJson = {
        "realtime": {
          "enabled": true,
          "protocolVersions": [2],
        },
      };

      final result = await api.discoverCapabilities();

      expect(result, isA<VoiceCapabilitiesContractFailure>());
    },
  );

  test("Given disabled protocol-one capabilities When discovering voice support Then preserves capability for async context", () async {
    publicClient.responseJson = {
      "realtime": {
        "enabled": false,
        "protocolVersions": [1],
      },
    };

    final result = await api.discoverCapabilities();

    expect(result, isA<VoiceCapabilitiesAvailable>());
    final capabilities = (result as VoiceCapabilitiesAvailable).capabilities;
    expect(capabilities.canUseRealtimeProtocol1, isFalse);
    expect(capabilities.supportsProtocol1, isTrue);
  });

  test("Given a hung async upload When transcribing Then timeout is exactly 120 seconds", () {
    fakeAsync((async) {
      authClient.hang = true;

      ApiResponse<String>? result;
      api
          .transcribe(
            "test/fixtures/voice_realtime_protocol_v1.json",
            mimeType: "application/json",
            projectKey: null,
            capabilities: null,
          )
          .then((value) {
            result = value;
          });

      async.elapse(const Duration(seconds: 119));
      async.flushMicrotasks();
      expect(result, isNull);

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(result, isA<ErrorResponse<String>>());
    });
  });

  test(
    "Given async transcription context When protocol support is observed Then sends only opaque project key",
    () async {
      const capabilities = VoiceCapabilities(realtimeEnabled: false, protocolVersions: [1]);
      final projectKey = deriveProjectGlossaryKey("project-123");

      await api.transcribe(
        "test/fixtures/voice_realtime_protocol_v1.json",
        mimeType: "application/json",
        projectKey: projectKey,
        capabilities: capabilities,
      );

      expect(authClient.timeout, const Duration(seconds: 120));
      expect(authClient.fields.single, {"projectKey": projectKey});
      expect(authClient.fields.single.toString(), isNot(contains("project-123")));
    },
  );

  test("Given old-server async fallback When transcribing Then omits projectKey exactly", () async {
    await api.transcribe(
      "test/fixtures/voice_realtime_protocol_v1.json",
      mimeType: "application/json",
      projectKey: deriveProjectGlossaryKey("project-123"),
      capabilities: null,
    );

    expect(authClient.fields.single, isNull);
  });
}
