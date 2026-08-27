import "package:freezed_annotation/freezed_annotation.dart";

import "../../voice/project_glossary_key.dart";

part "project_glossary_words_request.freezed.dart";
part "project_glossary_words_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class ProjectGlossaryWordsRequest with _$ProjectGlossaryWordsRequest {
  const factory({
    @ProjectGlossaryKeyJsonConverter() required ProjectGlossaryKey projectKey,
    required String? bridgeId,
    required List<String> words,
  }) = _ProjectGlossaryWordsRequest;

  factory fromJson(Map<String, dynamic> json) => _$ProjectGlossaryWordsRequestFromJson(json);
}
