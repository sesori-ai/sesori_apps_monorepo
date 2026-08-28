import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/api/models/realtime_voice_protocol.dart";
import "package:sesori_dart_core/src/api/models/voice_capabilities_api_model.dart";
import "package:test/test.dart";

class MockVoiceApi() extends Mock implements VoiceApi;

class MockRealtimeVoiceApi() extends Mock implements RealtimeVoiceApi;

void main() {
  setUpAll(() {
    registerFallbackValue(const RealtimeAudioFormat(sampleRate: 16000));
  });

  late MockVoiceApi api;
  late MockRealtimeVoiceApi realtimeApi;
  late VoiceRepository repository;

  setUp(() {
    api = MockVoiceApi();
    realtimeApi = MockRealtimeVoiceApi();
    repository = VoiceRepository(api: api, realtimeApi: realtimeApi);
  });

  test("maps capability API responses into closed product outcomes", () async {
    when(api.discoverCapabilities).thenAnswer(
      (_) async => ApiResponse.success(
        const VoiceCapabilitiesApiModel(realtimeEnabled: true, protocolVersions: [1]),
      ),
    );
    final available = await repository.discoverCapabilities();
    expect(
      available,
      isA<VoiceCapabilitiesAvailable>().having(
        (value) => value.capabilities.canUseRealtimeProtocol1,
        "canUseRealtimeProtocol1",
        isTrue,
      ),
    );

    when(api.discoverCapabilities).thenAnswer(
      (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)),
    );
    expect(await repository.discoverCapabilities(), isA<VoiceCapabilitiesAsyncFallback>());

    when(api.discoverCapabilities).thenAnswer(
      (_) async => ApiResponse.error(ApiError.jsonParsing("bad capabilities")),
    );
    expect(await repository.discoverCapabilities(), isA<VoiceCapabilitiesContractFailure>());

    when(api.discoverCapabilities).thenAnswer(
      (_) async => ApiResponse.success(
        const VoiceCapabilitiesApiModel(realtimeEnabled: true, protocolVersions: [2]),
      ),
    );
    expect(await repository.discoverCapabilities(), isA<VoiceCapabilitiesContractFailure>());
  });

  test("maps realtime open failures into closed repository outcomes", () async {
    final cases = <Exception, Type>{
      const RealtimeVoiceOpenAuthenticationException(cause: null, httpStatus: 401): VoiceRealtimeOpenNotAuthenticated,
      const RealtimeVoiceOpenHandshakeNotFoundException(cause: null, httpStatus: 404): VoiceRealtimeOpenAsyncFallback,
      const RealtimeVoiceOpenHandshakeRateLimitedException(cause: null, httpStatus: 429):
          VoiceRealtimeOpenAsyncFallback,
      const RealtimeVoiceOpenTimeoutException(cause: null, httpStatus: null): VoiceRealtimeOpenAsyncFallback,
      const RealtimeVoiceOpenTransportException(cause: null, httpStatus: null): VoiceRealtimeOpenAsyncFallback,
      const RealtimeVoiceProtocolException("bad realtime contract"): VoiceRealtimeOpenContractFailure,
    };

    for (final entry in cases.entries) {
      reset(realtimeApi);
      when(
        () => realtimeApi.start(
          audio: any(named: "audio"),
          projectKey: any(named: "projectKey"),
        ),
      ).thenThrow(entry.key);

      final outcome = await repository.openRealtime(
        audio: const VoiceRealtimeAudioFormat(sampleRate: 16000),
        projectKey: deriveProjectGlossaryKey(projectId: "project-123"),
      );
      expect(outcome.runtimeType, entry.value);
    }
  });

  test("maps success and forwards the typed artifact facts", () async {
    when(
      () => api.transcribe(
        audioFilePath: any(named: "audioFilePath"),
        mimeType: any(named: "mimeType"),
        projectKey: any(named: "projectKey"),
      ),
    ).thenAnswer(
      (_) async => const VoiceTranscriptionApiResult.success(transcript: "hello"),
    );

    final outcome = await repository.transcribe(
      audioFilePath: "/tmp/voice.m4a",
      mimeType: "audio/mp4",
      projectKey: null,
    );

    expect(
      outcome,
      isA<VoiceTranscriptionSuccess>().having((value) => value.transcript, "transcript", "hello"),
    );
    verify(
      () => api.transcribe(
        audioFilePath: "/tmp/voice.m4a",
        mimeType: "audio/mp4",
        projectKey: null,
      ),
    ).called(1);
  });

  test("maps authoritative true separately from false, omitted, and malformed metadata", () async {
    final cases = <({VoiceTranscriptionApiResult result, Type outcomeType})>[
      (
        result: VoiceTranscriptionApiResult.failure(
          error: ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null),
          retryable: true,
        ),
        outcomeType: VoiceTranscriptionRetryableServerFailure,
      ),
      (
        result: VoiceTranscriptionApiResult.failure(
          error: ApiError.nonSuccessCode(errorCode: 400, rawErrorString: null),
          retryable: false,
        ),
        outcomeType: VoiceTranscriptionTerminalServerFailure,
      ),
      (
        result: VoiceTranscriptionApiResult.failure(
          error: ApiError.nonSuccessCode(errorCode: 500, rawErrorString: null),
          retryable: null,
        ),
        outcomeType: VoiceTranscriptionTerminalServerFailure,
      ),
    ];

    for (final candidate in cases) {
      reset(api);
      when(
        () => api.transcribe(
          audioFilePath: any(named: "audioFilePath"),
          mimeType: any(named: "mimeType"),
          projectKey: any(named: "projectKey"),
        ),
      ).thenAnswer((_) async => candidate.result);

      final outcome = await repository.transcribe(
        audioFilePath: "/tmp/voice.m4a",
        mimeType: "audio/mp4",
        projectKey: null,
      );

      expect(outcome.runtimeType, candidate.outcomeType);
    }
  });

  test("maps every non-server API failure without leaking transport types upward", () async {
    final cases = <ApiError, Type>{
      ApiError.notAuthenticated(): VoiceTranscriptionNotAuthenticated,
      ApiError.dartHttpClient(Exception("offline")): VoiceTranscriptionNetworkFailure,
      ApiError.generic(): VoiceTranscriptionUnexpectedFailure,
      ApiError.jsonParsing("bad json"): VoiceTranscriptionEmptyTranscript,
      ApiError.emptyResponse(): VoiceTranscriptionEmptyTranscript,
    };

    for (final MapEntry(key: error, value: outcomeType) in cases.entries) {
      reset(api);
      when(
        () => api.transcribe(
          audioFilePath: any(named: "audioFilePath"),
          mimeType: any(named: "mimeType"),
          projectKey: any(named: "projectKey"),
        ),
      ).thenAnswer(
        (_) async => VoiceTranscriptionApiResult.failure(error: error, retryable: null),
      );

      final outcome = await repository.transcribe(
        audioFilePath: "/tmp/voice.m4a",
        mimeType: "audio/mp4",
        projectKey: null,
      );

      expect(outcome.runtimeType, outcomeType);
    }
  });
}
