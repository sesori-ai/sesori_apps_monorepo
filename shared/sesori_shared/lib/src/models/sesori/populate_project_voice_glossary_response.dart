import "package:freezed_annotation/freezed_annotation.dart";

part "populate_project_voice_glossary_response.freezed.dart";
part "populate_project_voice_glossary_response.g.dart";

/// Returns the bridge-derived opaque key for the population request so the
/// active recording uses exactly the same bridge/project namespace.
@Freezed(fromJson: true, toJson: true)
sealed class PopulateProjectVoiceGlossaryResponse with _$PopulateProjectVoiceGlossaryResponse {
  const factory({required String projectKey}) = _PopulateProjectVoiceGlossaryResponse;

  factory fromJson(Map<String, dynamic> json) => _$PopulateProjectVoiceGlossaryResponseFromJson(json);
}
