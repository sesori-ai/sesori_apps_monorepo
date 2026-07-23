import "package:freezed_annotation/freezed_annotation.dart";

part "codex_turn_input_dto.freezed.dart";
part "codex_turn_input_dto.g.dart";

@Freezed(unionKey: "type", fromJson: false, toJson: true)
sealed class CodexTurnInputDto with _$CodexTurnInputDto {
  @FreezedUnionValue("text")
  const factory CodexTurnInputDto.text({
    required String text,
    @JsonKey(name: "text_elements") @Default(<Object?>[]) List<Object?> textElements,
  }) = CodexTurnTextInputDto;

  @FreezedUnionValue("localImage")
  const factory CodexTurnInputDto.localImage({
    required String path,
  }) = CodexTurnLocalImageInputDto;

  @FreezedUnionValue("image")
  const factory CodexTurnInputDto.image({
    required String url,
  }) = CodexTurnImageInputDto;
}
