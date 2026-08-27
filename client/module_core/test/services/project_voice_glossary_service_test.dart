import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
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
    ).thenAnswer((_) async => ApiResponse.success(null));

    await service.requestPopulation(projectId: "project-1");

    verify(() => projectRepository.populateVoiceGlossary(projectId: "project-1")).called(1);
  });

  test("an older bridge without the capability degrades without throwing", () async {
    when(
      () => projectRepository.populateVoiceGlossary(projectId: "project-1"),
    ).thenAnswer(
      (_) async => ApiResponse.error(
        ApiError.nonSuccessCode(errorCode: 404, rawErrorString: "route not found"),
      ),
    );

    await expectLater(service.requestPopulation(projectId: "project-1"), completes);
  });

  test("an unexpected relay failure remains best effort", () async {
    when(
      () => projectRepository.populateVoiceGlossary(projectId: "project-1"),
    ).thenThrow(StateError("relay unavailable"));

    await expectLater(service.requestPopulation(projectId: "project-1"), completes);
  });
}
