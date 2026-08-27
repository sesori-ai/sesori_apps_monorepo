import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/repositories/models/project_voice_glossary_population_result.dart";
import "package:sesori_dart_core/src/services/project_voice_glossary_service.dart";
import "package:sesori_dart_core/testing.dart";
import "package:test/test.dart";

void main() {
  late MockProjectRepository projectRepository;
  late ProjectVoiceGlossaryService service;

  setUp(() {
    projectRepository = MockProjectRepository();
    service = ProjectVoiceGlossaryService(projectRepository: projectRepository);
  });

  test("requests the explicit bridge capability for the current project", () async {
    when(
      () => projectRepository.populateVoiceGlossary(projectId: "project-1"),
    ).thenAnswer(
      (_) async => const ProjectVoiceGlossaryPopulationAvailable(
        projectKey: "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      ),
    );

    expect(
      await service.requestPopulation(projectId: "project-1"),
      "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    );
    verify(() => projectRepository.populateVoiceGlossary(projectId: "project-1")).called(1);
  });

  test("an invalid bridge response degrades without forwarding a raw identifier", () async {
    when(
      () => projectRepository.populateVoiceGlossary(projectId: "project-1"),
    ).thenAnswer(
      (_) async => const ProjectVoiceGlossaryPopulationUnavailable(
        error: FormatException("Bridge returned an invalid project glossary key"),
      ),
    );

    expect(await service.requestPopulation(projectId: "project-1"), isNull);
  });

  test("an older bridge without the capability degrades without throwing", () async {
    when(
      () => projectRepository.populateVoiceGlossary(projectId: "project-1"),
    ).thenAnswer(
      (_) async => ProjectVoiceGlossaryPopulationUnavailable(
        error: ApiError.nonSuccessCode(errorCode: 404, rawErrorString: "route not found"),
      ),
    );

    expect(await service.requestPopulation(projectId: "project-1"), isNull);
  });

  test("an unexpected relay failure remains best effort", () async {
    when(
      () => projectRepository.populateVoiceGlossary(projectId: "project-1"),
    ).thenThrow(StateError("relay unavailable"));

    expect(await service.requestPopulation(projectId: "project-1"), isNull);
  });
}
