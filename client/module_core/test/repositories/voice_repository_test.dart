import "dart:async";
import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/api/models/realtime_voice_protocol.dart";
import "package:sesori_dart_core/src/api/models/voice_capabilities_api_model.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

class MockVoiceApi() extends Mock implements VoiceApi;

class MockVoiceCapabilitiesApi() extends Mock implements VoiceCapabilitiesApi;

class MockRealtimeVoiceApi() extends Mock implements RealtimeVoiceApi;

class _RepositoryRealtimeChannel({required final StreamController<Object?> controller})
    extends Mock
    implements WebSocketChannel {
  final _sink = _RepositoryRealtimeSink();

  @override
  Stream<dynamic> get stream => controller.stream;

  @override
  WebSocketSink get sink => _sink;
}

class _RepositoryRealtimeSink() extends Mock implements WebSocketSink {
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(const RealtimeAudioFormat(sampleRate: 16000));
    registerFallbackValue(ProjectGlossaryKey.parse(value: "prj_v1_${List.filled(43, "a").join()}"));
  });

  late MockVoiceApi api;
  late MockVoiceCapabilitiesApi capabilitiesApi;
  late MockRealtimeVoiceApi realtimeApi;
  late VoiceRepository repository;
  final projectKey = ProjectGlossaryKey.parse(value: "prj_v1_${List.filled(43, "a").join()}");

  setUp(() {
    api = MockVoiceApi();
    capabilitiesApi = MockVoiceCapabilitiesApi();
    realtimeApi = MockRealtimeVoiceApi();
    repository = VoiceRepository(
      api: api,
      capabilitiesApi: capabilitiesApi,
      realtimeApi: realtimeApi,
    );
  });

  test("maps capability API responses into closed product outcomes", () async {
    when(capabilitiesApi.discover).thenAnswer(
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

    when(capabilitiesApi.discover).thenAnswer(
      (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)),
    );
    expect(await repository.discoverCapabilities(), isA<VoiceCapabilitiesAsyncFallback>());

    when(capabilitiesApi.discover).thenAnswer(
      (_) async => ApiResponse.error(ApiError.jsonParsing("bad capabilities")),
    );
    expect(await repository.discoverCapabilities(), isA<VoiceCapabilitiesContractFailure>());

    when(capabilitiesApi.discover).thenAnswer(
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
        projectKey: projectKey,
      );
      expect(outcome.runtimeType, entry.value);
    }
  });

  test("preserves every server completion reason in repository events", () async {
    const cases = {
      RealtimeCompleteReason.finished: VoiceRealtimeCompletionReason.finished,
      RealtimeCompleteReason.sessionLimit: VoiceRealtimeCompletionReason.sessionLimit,
      RealtimeCompleteReason.quotaLimit: VoiceRealtimeCompletionReason.quotaLimit,
    };

    for (final MapEntry(key: apiReason, value: domainReason) in cases.entries) {
      final inbound = StreamController<Object?>.broadcast();
      final apiSession = RealtimeVoiceSession(
        channel: _RepositoryRealtimeChannel(controller: inbound),
      );
      when(
        () => realtimeApi.start(
          audio: any(named: "audio"),
          projectKey: any(named: "projectKey"),
        ),
      ).thenAnswer((_) async => apiSession);

      final outcome = await repository.openRealtime(
        audio: const VoiceRealtimeAudioFormat(sampleRate: 16000),
        projectKey: projectKey,
      );
      final connection = (outcome as VoiceRealtimeOpened).connection;
      final eventFuture = connection.events.first;
      inbound.add(
        jsonEncode({
          "type": "complete",
          "reason": apiReason.wireName,
          "dailySecondsRemaining": 0,
        }),
      );

      expect(
        await eventFuture,
        isA<VoiceRealtimeCompleted>().having((event) => event.reason, "reason", domainReason),
      );
      await inbound.close();
    }
  });

  test("preserves the originating realtime event-stream stack", () async {
    final inbound = StreamController<Object?>.broadcast();
    addTearDown(inbound.close);
    final apiSession = RealtimeVoiceSession(
      channel: _RepositoryRealtimeChannel(controller: inbound),
    );
    when(
      () => realtimeApi.start(
        audio: any(named: "audio"),
        projectKey: any(named: "projectKey"),
      ),
    ).thenAnswer((_) async => apiSession);

    final outcome = await repository.openRealtime(
      audio: const VoiceRealtimeAudioFormat(sampleRate: 16000),
      projectKey: projectKey,
    );
    final connection = (outcome as VoiceRealtimeOpened).connection;
    final eventFuture = connection.events.first;
    final origin = StackTrace.fromString("socket event origin");
    inbound.addError(StateError("socket failed"), origin);

    expect(
      await eventFuture,
      isA<VoiceRealtimeFailed>()
          .having((event) => event.failure.innerError, "innerError", isA<StateError>())
          .having((event) => event.failure.innerStackTrace, "innerStackTrace", same(origin)),
    );
  });

  test("maps success and forwards typed artifact and glossary context", () async {
    when(
      () => api.transcribe(
        audioFilePath: any(named: "audioFilePath"),
        mimeType: any(named: "mimeType"),
        projectGlossaryKey: any(named: "projectGlossaryKey"),
      ),
    ).thenAnswer(
      (_) async => const VoiceTranscriptionApiResult.success(transcript: "hello"),
    );

    final outcome = await repository.transcribe(
      audioFilePath: "/tmp/voice.m4a",
      mimeType: "audio/mp4",
      projectGlossaryKey: projectKey,
    );

    expect(
      outcome,
      isA<VoiceTranscriptionSuccess>().having((value) => value.transcript, "transcript", "hello"),
    );
    verify(
      () => api.transcribe(
        audioFilePath: "/tmp/voice.m4a",
        mimeType: "audio/mp4",
        projectGlossaryKey: projectKey,
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
          projectGlossaryKey: any(named: "projectGlossaryKey"),
        ),
      ).thenAnswer((_) async => candidate.result);

      final outcome = await repository.transcribe(
        audioFilePath: "/tmp/voice.m4a",
        mimeType: "audio/mp4",
        projectGlossaryKey: null,
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
          projectGlossaryKey: any(named: "projectGlossaryKey"),
        ),
      ).thenAnswer(
        (_) async => VoiceTranscriptionApiResult.failure(error: error, retryable: null),
      );

      final outcome = await repository.transcribe(
        audioFilePath: "/tmp/voice.m4a",
        mimeType: "audio/mp4",
        projectGlossaryKey: null,
      );

      expect(outcome.runtimeType, outcomeType);
    }
  });
}
