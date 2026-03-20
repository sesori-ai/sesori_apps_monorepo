import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_prompt_part.freezed.dart";

part "plugin_prompt_part.g.dart";

@freezed
sealed class PluginPromptPart with _$PluginPromptPart {
  const factory PluginPromptPart({
    required String type,
    String? text,
  }) = _PluginPromptPart;
}
