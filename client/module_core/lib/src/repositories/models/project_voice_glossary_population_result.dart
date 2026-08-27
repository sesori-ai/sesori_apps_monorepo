sealed class const ProjectVoiceGlossaryPopulationResult();

final class const ProjectVoiceGlossaryPopulationAvailable({required final String projectKey})
    extends ProjectVoiceGlossaryPopulationResult;

final class const ProjectVoiceGlossaryPopulationUnavailable({required final Object error})
    extends ProjectVoiceGlossaryPopulationResult;
