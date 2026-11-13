import "package:freezed_annotation/freezed_annotation.dart";

part "codex_turn_input_dto.freezed.dart";
part "codex_turn_input_dto.g.dart";

@Freezed(unionKey: "type", fromJson: false, toJson: true)
sealed class CodexTurnInputDto with _$CodexTurnInputDto {
  @FreezedUnionValue("text")
  const factory text({
    required String text,
    @JsonKey(name: "text_elements") @Default(<Object?>[]) List<Object?> textElements,
  }) = CodexTurnTextInputDto;

  @FreezedUnionValue("localImage")
  const factory localImage({
    required String path,
  }) = CodexTurnLocalImageInputDto;

  @FreezedUnionValue("image")
  const factory image({
    required String url,
  }) = CodexTurnImageInputDto;

  /// Names the skill a `\$name` text input invokes, so Codex's `userMessage`
  /// item records which skill the user picked.
  @FreezedUnionValue("skill")
  const factory skill({
    required String name,
    required String path,
  }) = CodexTurnSkillInputDto;
}
