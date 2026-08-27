import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/repositories/voice_repository.dart";
import "package:sesori_dart_core/testing.dart";
import "package:test/test.dart";

void main() {
  test("delegates scoped transcription through the voice API boundary", () async {
    const projectKey = "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    final voiceApi = MockVoiceApi();
    final repository = VoiceRepository(api: voiceApi);
    when(
      () => voiceApi.transcribe(
        audioFilePath: "/tmp/voice.m4a",
        mimeType: "audio/mp4",
        projectKey: projectKey,
      ),
    ).thenAnswer((_) async => ApiResponse.success("transcript"));

    final response = await repository.transcribe(
      audioFilePath: "/tmp/voice.m4a",
      mimeType: "audio/mp4",
      projectKey: projectKey,
    );

    expect(response, ApiResponse.success("transcript"));
  });
}
