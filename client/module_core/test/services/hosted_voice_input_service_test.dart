import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/services/hosted_voice_input_service.dart";
import "package:sesori_dart_core/testing.dart";
import "package:test/test.dart";

void main() {
  setUpAll(registerCoreFallbackValues);

  late MockVoiceRepository voiceRepository;
  late MockProjectVoiceGlossaryService glossaryService;
  late HostedVoiceInputService service;

  setUp(() {
    voiceRepository = MockVoiceRepository();
    glossaryService = MockProjectVoiceGlossaryService();
    service = HostedVoiceInputService(
      voiceRepository: voiceRepository,
      projectVoiceGlossaryService: glossaryService,
    );
  });

  test("uses the bridge-returned key for the matching active recording", () async {
    const projectKey = "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    when(() => glossaryService.requestPopulation(projectId: "project-1")).thenAnswer((_) async => projectKey);
    when(
      () => voiceRepository.transcribe(
        audioFilePath: "/tmp/voice.m4a",
        mimeType: "audio/mp4",
        projectKey: projectKey,
      ),
    ).thenAnswer((_) async => ApiResponse.success("transcript"));

    service.recordingStarted(projectId: "project-1");
    await Future<void>.delayed(Duration.zero);
    final response = await service.transcribe(
      audioFilePath: "/tmp/voice.m4a",
      mimeType: "audio/mp4",
      projectId: "project-1",
    );

    expect(response, ApiResponse.success("transcript"));
  });

  test("a recording without project context stays unscoped without a bridge request", () async {
    when(
      () => voiceRepository.transcribe(
        audioFilePath: "/tmp/voice.m4a",
        mimeType: "audio/mp4",
        projectKey: null,
      ),
    ).thenAnswer((_) async => ApiResponse.success("transcript"));

    service.recordingStarted(projectId: null);
    await service.transcribe(
      audioFilePath: "/tmp/voice.m4a",
      mimeType: "audio/mp4",
      projectId: null,
    );

    verifyNever(() => glossaryService.requestPopulation(projectId: any(named: "projectId")));
  });

  test("a pending glossary request never delays unscoped transcription", () async {
    final population = Completer<String?>();
    when(() => glossaryService.requestPopulation(projectId: "project-1")).thenAnswer((_) => population.future);
    when(
      () => voiceRepository.transcribe(
        audioFilePath: "/tmp/voice.m4a",
        mimeType: "audio/mp4",
        projectKey: null,
      ),
    ).thenAnswer((_) async => ApiResponse.success("transcript"));

    service.recordingStarted(projectId: "project-1");
    final response = await service.transcribe(
      audioFilePath: "/tmp/voice.m4a",
      mimeType: "audio/mp4",
      projectId: "project-1",
    );

    expect(response, ApiResponse.success("transcript"));
    population.complete(null);
    await Future<void>.delayed(Duration.zero);
  });

  test("late keys and stale cleanup cannot cross recording generations", () async {
    const projectKey = "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    final firstPopulation = Completer<String?>();
    final secondPopulation = Completer<String?>();
    when(() => glossaryService.requestPopulation(projectId: "project-1")).thenAnswer((_) => firstPopulation.future);
    when(() => glossaryService.requestPopulation(projectId: "project-2")).thenAnswer((_) => secondPopulation.future);
    when(
      () => voiceRepository.transcribe(
        audioFilePath: "/tmp/voice.m4a",
        mimeType: "audio/mp4",
        projectKey: projectKey,
      ),
    ).thenAnswer((_) async => ApiResponse.success("transcript"));

    final firstGeneration = service.recordingStarted(projectId: "project-1");
    service.recordingFinished(recordingGeneration: firstGeneration);
    service.recordingStarted(projectId: "project-2");
    secondPopulation.complete(projectKey);
    await Future<void>.delayed(Duration.zero);

    // A delayed finally block from recording one must not invalidate recording two.
    service.recordingFinished(recordingGeneration: firstGeneration);
    firstPopulation.complete(projectKey);
    await Future<void>.delayed(Duration.zero);
    await service.transcribe(
      audioFilePath: "/tmp/voice.m4a",
      mimeType: "audio/mp4",
      projectId: "project-2",
    );

    verify(
      () => voiceRepository.transcribe(
        audioFilePath: "/tmp/voice.m4a",
        mimeType: "audio/mp4",
        projectKey: projectKey,
      ),
    ).called(1);
  });
}
