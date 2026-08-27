import "package:freezed_annotation/freezed_annotation.dart";

part "project_glossary_response.freezed.dart";
part "project_glossary_response.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class ProjectGlossaryWordsResponse with _$ProjectGlossaryWordsResponse {
  const factory({required List<String> words}) = _ProjectGlossaryWordsResponse;

  factory fromJson(Map<String, dynamic> json) => _$ProjectGlossaryWordsResponseFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class ProjectGlossaryAddedWordsResponse with _$ProjectGlossaryAddedWordsResponse {
  const factory({required List<String> added}) = _ProjectGlossaryAddedWordsResponse;

  factory fromJson(Map<String, dynamic> json) => _$ProjectGlossaryAddedWordsResponseFromJson(json);
}
