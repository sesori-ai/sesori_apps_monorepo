import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class MockVoiceApi() extends Mock implements VoiceApi;

void main() {
  late MockVoiceApi api;
  late VoiceRepository repository;

  setUp(() {
    api = MockVoiceApi();
    repository = VoiceRepository(api: api);
  });

  test("maps success and forwards the typed artifact facts", () async {
    when(
      () => api.transcribe(
        audioFilePath: any(named: "audioFilePath"),
        mimeType: any(named: "mimeType"),
      ),
    ).thenAnswer((_) async => ApiResponse.success("hello"));

    final outcome = await repository.transcribe(
      audioFilePath: "/tmp/voice.m4a",
      mimeType: "audio/mp4",
    );

    expect(outcome, isA<VoiceTranscriptionSuccess>().having((value) => value.transcript, "transcript", "hello"));
    verify(
      () => api.transcribe(
        audioFilePath: "/tmp/voice.m4a",
        mimeType: "audio/mp4",
      ),
    ).called(1);
  });

  test("maps every current API failure without leaking transport types upward", () async {
    final cases = <ApiError, Type>{
      ApiError.notAuthenticated(): VoiceTranscriptionNotAuthenticated,
      ApiError.nonSuccessCode(errorCode: 503, rawErrorString: "unavailable"): VoiceTranscriptionServerFailure,
      ApiError.dartHttpClient(Exception("offline")): VoiceTranscriptionNetworkFailure,
      ApiError.generic(): VoiceTranscriptionNetworkFailure,
      ApiError.jsonParsing("bad json"): VoiceTranscriptionEmptyTranscript,
      ApiError.emptyResponse(): VoiceTranscriptionEmptyTranscript,
    };

    for (final MapEntry(key: error, value: outcomeType) in cases.entries) {
      reset(api);
      when(
        () => api.transcribe(
          audioFilePath: any(named: "audioFilePath"),
          mimeType: any(named: "mimeType"),
        ),
      ).thenAnswer((_) async => ApiResponse<String>.error(error));

      final outcome = await repository.transcribe(
        audioFilePath: "/tmp/voice.m4a",
        mimeType: "audio/mp4",
      );

      expect(outcome.runtimeType, outcomeType);
      if (outcome case VoiceTranscriptionServerFailure(:final statusCode)) {
        expect(statusCode, 503);
      }
    }
  });
}
