import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart" show ProjectGlossaryKey;
import "package:test/test.dart";

class MockVoiceApi() extends Mock implements VoiceApi;

void main() {
  late MockVoiceApi api;
  late VoiceRepository repository;

  setUp(() {
    api = MockVoiceApi();
    repository = VoiceRepository(api: api);
  });

  test("maps success and forwards typed artifact and glossary context", () async {
    final glossaryKey = ProjectGlossaryKey.parse(
      value: "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ",
    );
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
      projectGlossaryKey: glossaryKey,
    );

    expect(
      outcome,
      isA<VoiceTranscriptionSuccess>().having((value) => value.transcript, "transcript", "hello"),
    );
    verify(
      () => api.transcribe(
        audioFilePath: "/tmp/voice.m4a",
        mimeType: "audio/mp4",
        projectGlossaryKey: glossaryKey,
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
